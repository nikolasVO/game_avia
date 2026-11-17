import asyncio
import os
import time
import httpx
from orchestrator.settings import owner_id

class Telegram:
    def __init__(self, store):
        self.store=store
        self.owner=owner_id()
        token=os.environ["TELEGRAM_BOT_TOKEN"]
        self.base="https://api.telegram.org/bot"+token+"/"
    def authorized(self, update):
        item=update.get("callback_query") or update.get("message") or {}
        msg=item.get("message",{}) if "callback_query" in update else item
        return (item.get("from",{}).get("id")==self.owner and
                msg.get("chat",{}).get("id")==self.owner and msg.get("chat",{}).get("type")=="private")
    def command(self,text):
        cmd,*rest=text.split(maxsplit=1)
        arg=rest[0] if rest else ""
        if cmd in ("/start","/help"):
            return "GAME_AVIA: пришлите задачу текстом. /status /tasks /task <id> /models /providers /gpu /disk /assets /budget /pause /resume /cancel <id> /report"
        if cmd in ("/status","/report"):
            return "Состояние среды: "+str(self.store.kv("doctor") or "проверка ожидается")+"\nАвтовыполнение: "+str(self.store.kv("paused") or "false")
        if cmd in ("/tasks","/assets"):
            rows=self.store.list_tasks()
            if cmd=="/assets": rows=[r for r in rows if r["kind"]=="asset"]
            return "\n".join(r["id"]+" "+r["status"]+" "+r["goal"][:100] for r in rows) or "Заданий нет."
        if cmd=="/task":
            r=self.store.get_task(arg)
            return (r["id"]+" "+r["status"]+"\n"+r["goal"]+"\n"+str(r["result"] or ""))[:3800] if r else "Задание не найдено."
        if cmd=="/pause": return "Автовыполнение приостановлено." if self.store.kv("paused","true") else ""
        if cmd=="/resume":
            self.store.kv("paused","false")
            return "Возобновлён приём доступных задач. Большой backlog требует денежного бюджета."
        if cmd=="/cancel":
            try: self.store.transition(arg,"cancelled","Отменено владельцем.");return "Задание отменено."
            except (KeyError,ValueError): return "Задание не найдено или уже завершено."
        if cmd=="/budget": return self.store.kv("budget_status") or "budget_not_configured: разрешены только конечные bootstrap-пробы; большой backlog не запускается."
        if cmd in ("/models","/providers","/gpu","/disk"):
            return self.store.kv(cmd[1:]) or "Проверка ещё не завершена."
        return "Неизвестная команда. /help"
    def ingest(self,update):
        if not self.authorized(update): return False
        uid=update.get("update_id")
        if not isinstance(uid,int): return False
        if "callback_query" in update:
            return self.store.ingest(uid,reply="Используйте команды /help; действие callback не выполнено.")
        text=update.get("message",{}).get("text","").strip()
        if not text: return self.store.ingest(uid,reply="Для задания нужен текст.")
        if text.startswith("/"):
            # Dedup before executing commands that can mutate state.
            with self.store.db() as c:
                if c.execute("SELECT 1 FROM telegram_updates WHERE update_id=?",(uid,)).fetchone(): return None
            return self.store.ingest(uid,reply=self.command(text))
        return self.store.ingest(uid,goal=text[:12000])
    async def call(self,method,data,timeout=35):
        try:
            async with httpx.AsyncClient(timeout=timeout) as client:
                r=await client.post(self.base+method,json=data)
            d=r.json()
            if not d.get("ok"):
                return {"ok":False,"retry_after":d.get("parameters",{}).get("retry_after",30),"code":d.get("error_code",r.status_code)}
            return d
        except (httpx.HTTPError,ValueError):
            return {"ok":False,"unknown":True,"retry_after":30}
    async def deliver_one(self):
        with self.store.db() as c:
            row=c.execute("SELECT * FROM notification_outbox WHERE status IN ('pending','unknown') AND next_at<=? ORDER BY rowid LIMIT 1",(time.time(),)).fetchone()
        if not row: return False
        r=await self.call("sendMessage",{"chat_id":self.owner,"text":row["text"]})
        with self.store.db() as c:
            if r.get("ok"):
                c.execute("UPDATE notification_outbox SET status='sent',message_id=?,attempts=attempts+1 WHERE event_id=?",(r["result"]["message_id"],row["event_id"]))
            else:
                c.execute("UPDATE notification_outbox SET status=?,attempts=attempts+1,next_at=? WHERE event_id=?",
                          ("unknown" if r.get("unknown") else "pending",time.time()+max(2,r["retry_after"]),row["event_id"]))
        return True
    async def run(self):
        info=await self.call("getWebhookInfo",{})
        if not info.get("ok") or info["result"].get("url"):
            raise RuntimeError("telegram_webhook_conflict_or_unavailable")
        while True:
            for _ in range(3):
                if not await self.deliver_one(): break
                await asyncio.sleep(1.1)
            offset=int(self.store.kv("telegram_offset") or 0)
            r=await self.call("getUpdates",{"offset":offset,"timeout":5,"allowed_updates":["message","callback_query"]},timeout=15)
            if r.get("ok"):
                for u in r["result"]:
                    self.ingest(u)
                    self.store.kv("telegram_offset",u["update_id"]+1)
            else:
                await asyncio.sleep(max(3,r.get("retry_after",5)))

