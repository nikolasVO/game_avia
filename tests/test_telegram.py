import os
import pytest
from orchestrator.store import Store
from integrations.telegram.bot import Telegram
@pytest.fixture
def bot(tmp_path,monkeypatch):
    for k,v in {"TELEGRAM_ADMIN_ID":"123","TELEGRAM_CHAT_ID":"123","TELEGRAM_ALLOWED_USER_IDS":"123","TELEGRAM_BOT_TOKEN":"test:token"}.items():monkeypatch.setenv(k,v)
    return Telegram(Store(tmp_path/"s.db"))
def update(uid=1,user=123,chat=123,kind="private",text="task"):
    return {"update_id":uid,"message":{"from":{"id":user},"chat":{"id":chat,"type":kind},"text":text}}
@pytest.mark.parametrize("user,chat,kind",[(2,123,"private"),(123,2,"private"),(123,123,"group")])
def test_reject_unauthorized(bot,user,chat,kind):
    assert bot.ingest(update(user=user,chat=chat,kind=kind)) is False
    assert not bot.store.list_tasks()
    with bot.store.db() as c:assert c.execute("SELECT COUNT(*) FROM notification_outbox").fetchone()[0]==0
def test_callback_auth(bot):
    u=update(user=2)
    u["callback_query"]={"from":{"id":2},"message":u.pop("message"),"data":"cancel"}
    assert bot.ingest(u) is False
def test_ingress_once(bot):
    assert bot.ingest(update())
    assert bot.ingest(update()) is None
    assert len(bot.store.list_tasks())==1
async def test_pinned_recipient(bot):
    bot.store.event(None,"hello")
    calls=[]
    async def call(method,data,**kw):
        calls.append(data);return {"ok":True,"result":{"message_id":9}}
    bot.call=call
    assert await bot.deliver_one()
    assert calls==[{"chat_id":123,"text":"[system] hello"}]

