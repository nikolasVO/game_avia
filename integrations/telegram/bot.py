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
        with self.store.db() as c:c.execute("UPDATE notification_outbox SET status='unknown' WHERE status='sending'")
    def authorized(self, update):
        item=update.get("callback_query") or update.get("message") or {}
        msg=item.get("message",{}) if "callback_query" in update else item
        return (item.get("from",{}).get("id")==self.owner and
                msg.get("chat",{}).get("id")==self.owner and msg.get("chat",{}).get("type")=="private")
    def command(self,text,connection=None):
        def kv(key,value=None):
            if connection is None:return self.store.kv(key,value)
            if value is not None:
                connection.execute("INSERT OR REPLACE INTO kv VALUES(?,?)",(key,str(value)));return str(value)
            r=connection.execute("SELECT value FROM kv WHERE key=?",(key,)).fetchone()
            return r[0] if r else None
        cmd,*rest=text.split(maxsplit=1)
        arg=rest[0] if rest else ""
        if cmd in ("/start","/help"):
            return "GAME_AVIA: пришлите задачу текстом. /status /tasks /task <id> /models /providers /gpu /disk /assets /budget /pause /resume /cancel <id> /report"
        if cmd in ("/status","/report"):
            return "Состояние среды: "+str(kv("doctor") or "проверка ожидается")+"\nАвтовыполнение: "+str(kv("paused") or "false")
        if cmd in ("/tasks","/assets"):
            rows=self.store.list_tasks()
            if cmd=="/assets": rows=[r for r in rows if r["kind"]=="asset"]
            return "\n".join(r["id"]+" "+r["status"]+" "+r["goal"][:100] for r in rows) or "Заданий нет."
        if cmd=="/task":
            r=self.store.get_task(arg)
            return (r["id"]+" "+r["status"]+"\n"+r["goal"]+"\n"+str(r["result"] or ""))[:3800] if r else "Задание не найдено."
        if cmd=="/pause": return "Новые задания приостановлены. Для текущего используйте /cancel <id>." if kv("paused","true") else ""
        if cmd=="/resume":
            kv("paused","false")
            return "Возобновлён приём доступных задач. Большой backlog требует денежного бюджета."
        if cmd=="/cancel":
            try:
                row=connection.execute("SELECT status FROM tasks WHERE id=?",(arg,)).fetchone() if connection is not None else None
                if not row or row[0] in ("completed","failed","cancelled"):raise ValueError("not_active")
                connection.execute("UPDATE tasks SET status='cancelled',execution_status='cancelled' WHERE id=?",(arg,))
                self.store._event(connection,arg,"Отменено владельцем.","state")
                return "Задание отменено."
            except (KeyError,ValueError): return "Задание не найдено или уже завершено."
        if cmd=="/budget":
            with self.store.db() as c:
                row=c.execute("SELECT COALESCE(SUM(requests),0),COALESCE(SUM(tokens),0) FROM usage_ledger WHERE created>?",(time.time()-86400,)).fetchone()
            return (kv("budget_status") or "budget_not_configured")+f"\nЗа 24 часа: {row[0]} текстовых запросов; резерв токенов {row[1]}. Стоимость: cost_unknown."
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
            return self.store.ingest_command(uid,text,self.command)
        return self.store.ingest(uid,goal=text[:12000])
    async def call(self,method,data,timeout=35):
        try:
            async with httpx.AsyncClient(timeout=timeout) as client:
                r=await client.post(self.base+method,json=data)
            d=r.json()
            if not d.get("ok"):
                return {"ok":False,"retry_after":d.get("parameters",{}).get("retry_after",30),"code":d.get("error_code",r.status_code)}
            return d
        except (httpx.ConnectError,httpx.ConnectTimeout):
            return {"ok":False,"unknown":False,"retry_after":30}
        except (httpx.HTTPError,ValueError):
            return {"ok":False,"unknown":True,"retry_after":30}
    async def send_artifact(self,row):
        from pathlib import Path
        path=Path(row["artifact_path"])
        method="sendPhoto" if row["kind"]=="photo" else "sendDocument"
        field="photo" if row["kind"]=="photo" else "document"
        try:
            async with httpx.AsyncClient(timeout=60) as client:
                with path.open("rb") as f:
                    r=await client.post(self.base+method,data={"chat_id":str(self.owner),"caption":row["text"][:1000]},files={field:(path.name,f)})
            d=r.json()
            if d.get("ok"):return d
            return {"ok":False,"retry_after":d.get("parameters",{}).get("retry_after",60)}
        except (httpx.ConnectError,httpx.ConnectTimeout):return {"ok":False,"retry_after":30}
        except (httpx.HTTPError,OSError,ValueError):return {"ok":False,"unknown":True,"retry_after":30}
    async def deliver_one(self):
        with self.store.db() as c:
            c.execute("BEGIN IMMEDIATE")
            row=c.execute("SELECT * FROM notification_outbox WHERE status='pending' AND next_at<=? ORDER BY rowid LIMIT 1",(time.time(),)).fetchone()
            if row:c.execute("UPDATE notification_outbox SET status='sending' WHERE event_id=?",(row["event_id"],))
        if not row: return False
        r=await(self.send_artifact(row) if row["kind"]!="text" else self.call("sendMessage",{"chat_id":self.owner,"text":row["text"]}))
        with self.store.db() as c:
            if r.get("ok"):
                c.execute("UPDATE notification_outbox SET status='sent',message_id=?,attempts=attempts+1 WHERE event_id=?",(r["result"]["message_id"],row["event_id"]))
                task=c.execute("SELECT task_id FROM events WHERE id=?",(row["event_id"],)).fetchone()
                if task and task[0]:
                    unsent=c.execute("SELECT 1 FROM notification_outbox o JOIN events e ON e.id=o.event_id WHERE e.task_id=? AND o.status!='sent' LIMIT 1",(task[0],)).fetchone()
                    if not unsent:c.execute("UPDATE tasks SET notification_status='sent' WHERE id=?",(task[0],))
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

