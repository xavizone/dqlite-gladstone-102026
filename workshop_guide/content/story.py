"""The lab's story: cast, chapters, incident tickets and the Home timelines - one source for the live and static guides.
Edit the words here; the pages only decide where each piece appears."""
import streamlit as st

LAB = "lite"
ARC = ["The complaint", "Guard", "Catch and contain", "Operate"]

CAST = [
    {"name": "Sam", "role": "Operations manager, Riverside Leisure (the operator)", "icon": ":material/storefront:",
     "says": "Sees Nova every morning. Rings Gladstone when the numbers look wrong."},
    {"name": "Priya", "role": "Customer Success lead, Gladstone", "icon": ":material/support_agent:",
     "says": "Takes Sam's call. Needs an answer - ideally before Sam notices."},
    {"name": "You", "role": "On-call data engineer, Gladstone", "icon": ":material/engineering:",
     "says": "Own Riverside's Nova pipeline. Work in CoCo."},
]

CHAPTERS = {
    1: {"previously": "Nova went live for Riverside Leisure two weeks ago.",
        "who": "Sam", "quote": "Nova says we have more active members than our front desk can count, and today's revenue looks far too low.",
        "scene": "Priya forwards Sam's call to you with one line: *\"Can you tell me what's going on?\"*",
        "mission": "Find where those two numbers come from, and write down what they say on a good day."},
    2: {"previously": "You know where Nova's numbers come from and what a good day looks like.",
        "who": "Priya", "quote": "I never want to hear about this from Sam first again. Can we know before he does?",
        "scene": "Nothing is broken yet. This is your chance to put guards on the pipeline before the next bad batch.",
        "mission": "Turn \"what must always be true\" into checks, and make every failure tell someone."},
    3: {"previously": "Your guards are on, they all pass, and the incident log is empty.",
        "who": "Priya", "quote": "Your alert just logged incidents for Riverside. What happened, and is Nova showing it?",
        "scene": "Between 09:00 and 09:05 three things go wrong in Riverside's feed. Nobody has called yet.",
        "mission": "Explain each failure in one sentence, then stop new bad data reaching Nova."},
    4: {"previously": "You found three faults, logged them, and paused REPORTING.",
        "who": "Sam", "quote": "Quick one - how many active members do we really have? Two of your screens disagree.",
        "scene": "A fourth problem lands while you're working, and Priya needs one place to look before she calls Sam back.",
        "mission": "Give Priya a health view, catch the last fault, fix the data and watch the pipeline recover."},
}

TURNS = {
    1: {"changed": "You can name every layer between Riverside's database and Nova, and you have a clean baseline: 1,598 active members by status, 1,520 paid.",
        "next": "Next: make sure the next bad batch is caught before Sam opens Nova."},
    2: {"changed": "Riverside's pipeline is now checked every 5 minutes. A failure becomes an incident row - and an email for the critical ones - with no one watching.",
        "next": "Next: the facilitator breaks Riverside's feed. Let's see your guards work."},
    3: {"changed": "Priya has a root cause to send Sam, and REPORTING is paused, so no further bad batches reach Nova.",
        "next": "Next: one more fault, one place for Priya to look, and the fix."},
    4: {"changed": "Every check is OK again, the breaker closed by itself, and DQ_INCIDENTS keeps the timeline for the review.",
        "next": "Epilogue below."},
}

TICKETS = {
    "s3": {"id": "CS-1042", "time": "09:06", "from": "DQ_INCIDENT_ALERT (automatic)", "operator": "Riverside Leisure",
           "severity": "High", "status": "Open - no customer contact yet",
           "summary": "3 checks failing: duplicate members, negative payments, payments not fresh.",
           "note": "The alert opened this ticket. Sam hasn't called - you're ahead of him."},
    "s4": {"id": "CS-1043", "time": "09:12", "from": "Sam, Riverside Leisure (phone)", "operator": "Riverside Leisure",
           "severity": "Medium", "status": "Open",
           "summary": "\"Two of your screens disagree on active members.\"",
           "note": "No row is malformed this time. Only a business rule will catch it."},
}

TIMELINES = {
    "without": [("08:59", "Bifrost replays a merge batch; a refund bug sends negative payments"),
                ("09:01", "Nova refreshes with 150 extra members and today's revenue below zero"),
                ("10:40", "Sam opens Nova, then rings Customer Success"),
                ("11:30", "Priya raises a ticket; engineering starts digging"),
                ("Next day", "Root cause found by hand; Sam has been reporting wrong numbers all morning")],
    "with": [("08:59", "Same bad batch arrives"),
             ("09:05", "Scheduled checks fail: duplicates, negative amounts, freshness"),
             ("09:06", "Alert writes DQ_INCIDENTS; Priya gets an email"),
             ("09:06", "Circuit breaker pauses REPORTING - no further bad batches reach Nova"),
             ("09:15", "CoCo explains the batch; Priya calls Sam first: \"we know, it's being fixed\"")],
}

EPILOGUE = ("**Epilogue.** At 09:30 Priya calls Sam back with the cause, the fix and the time it was contained. "
            "Sam never saw a wrong number in his morning report. Next month, the same checks go on every operator "
            "database - see *Rolling out to every operator*.")

SAY_THIS = {
    0: "Riverside Leisure rang us this morning: Nova says too many members and too little revenue. Today you're the on-call engineer. In 30 minutes we'll go from the operator telling us, to us telling the operator.",
    1: "First, find where those two numbers come from - and write down what they say on a good day.",
    2: "Nothing is broken yet. Put guards on the pipeline now, so the next problem logs itself.",
    3: "I'm breaking Riverside's feed now. Watch your incident log - then tell me what happened before Sam calls.",
    4: "One more fault, and Priya needs one place to look. Build it, fix the data, and watch it heal.",
}


# ── renderers (native Streamlit, shared by the live and static guides) ──────────
def story_arc(current: int):
    labels = []
    for i, name in enumerate(ARC, 1):
        if i < current:
            labels.append(f":green-badge[:material/check: {name}]")
        elif i == current:
            labels.append(f":blue-badge[**{i}. {name}**]")
        else:
            labels.append(f":gray-badge[{i}. {name}]")
    st.markdown(" &nbsp;:material/arrow_forward:&nbsp; ".join(labels))


def chapter(n: int):
    c = CHAPTERS[n]
    with st.container(border=True):
        story_arc(n)
        st.caption(f":material/history: **Previously:** {c['previously']}")
        avatar = next(p["icon"] for p in CAST if p["name"] == c["who"])
        with st.chat_message(c["who"], avatar=avatar):
            st.markdown(f"**{c['who']}:** *\"{c['quote']}\"*")
        st.markdown(c["scene"])
        st.markdown(f":material/flag: **Your mission:** {c['mission']}")


def ticket(key: str):
    t = TICKETS[key]
    with st.container(border=True):
        h1, h2 = st.columns([3, 1], vertical_alignment="center")
        h1.markdown(f"#### :material/confirmation_number: {t['id']} - {t['operator']}")
        h2.markdown(f":red-badge[{t['severity']}]")
        st.markdown(f"**{t['summary']}**")
        st.caption(f"Opened {t['time']} by {t['from']} | {t['status']}")
        st.caption(f":material/lightbulb: {t['note']}")


def turn(n: int):
    t = TURNS[n]
    with st.container(border=True):
        st.markdown(f":material/auto_stories: **What changed:** {t['changed']}")
        st.caption(t["next"])


def cast():
    cols = st.columns(len(CAST))
    for col, p in zip(cols, CAST):
        with col.container(border=True, height="stretch"):
            st.markdown(f"##### {p['icon']} {p['name']}")
            st.caption(p["role"])
            st.markdown(p["says"])


def timelines():
    left, right = st.columns(2)
    for col, key, title, icon in [(left, "without", "A Tuesday without guards", ":material/sentiment_dissatisfied:"),
                                  (right, "with", "The same Tuesday with guards", ":material/verified_user:")]:
        with col.container(border=True, height="stretch"):
            st.markdown(f"##### {icon} {title}")
            for when, what in TIMELINES[key]:
                st.markdown(f"`{when}` {what}")


def epilogue():
    st.success(EPILOGUE, icon=":material/celebration:")
