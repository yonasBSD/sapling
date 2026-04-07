import datetime
import time

import bindings
from sapling import util


# reposetup is more compatible with debugruntest since it runs for every invocation.
def reposetup(ui, _repo):
    fakedate = ui.config("fakedate", "date", "1996-03-07 14:00:01Z")
    bindings.hgtime.setnowfortesting(fakedate)
    fakedate = util.parsedate(fakedate)[0]

    class fakedatetime(datetime.datetime):
        @staticmethod
        def now(tz=None):
            return datetime.datetime.fromtimestamp(fakedate, tz)

    datetime.datetime = fakedatetime

    def faketime():
        return fakedate

    time.time = faketime
