cat > ~/.jarvis/jarvis.py <<'PYEOF'
#!/usr/bin/env python3
"""J.A.R.V.I.S. — Just A Rather Very Intelligent System"""

import os, sys, re, json, math, random, shutil, subprocess, threading
import time, ast, operator, datetime, textwrap
import urllib.parse, urllib.request

R    = "\033[0m"
B    = "\033[1m"
DIM  = "\033[2m"
CY   = "\033[96m"
GD   = "\033[93m"
RD   = "\033[91m"
GR   = "\033[92m"
MG   = "\033[95m"

HOME_DIR  = os.path.expanduser("~")
BASE      = os.path.join(HOME_DIR, ".jarvis")
CONF_PATH = os.path.join(BASE, "config.json")

def clear():
    sys.stdout.write("\033[2J\033[H")
    sys.stdout.flush()

def conf_load():
    try:
        with open(CONF_PATH) as f:
            return json.load(f)
    except Exception:
        return {}

def conf_save(c):
    try:
        os.makedirs(BASE, exist_ok=True)
        with open(CONF_PATH, "w") as f:
            json.dump(c, f, indent=2)
    except Exception:
        pass

CONF  = conf_load()
MUTED = CONF.get("muted", False)
RATE  = CONF.get("rate", 180)
VOICE = CONF.get("voice", None)

PREFERRED_VOICES = ["Daniel", "Oliver", "Arthur", "Rishi"]

def detect_voice():
    try:
        out = subprocess.run(["say", "-v", "?"], capture_output=True,
                             text=True, timeout=8).stdout
    except Exception:
        return None
    for name in PREFERRED_VOICES:
        if re.search(r"^" + re.escape(name) + r"\s", out, re.M):
            return name
    return None

_speak_lock = threading.Lock()

def speak(text, block=True):
    if MUTED:
        return
    clean = re.sub(r"\x1b\[[0-9;]*m", "", text)
    clean = re.sub(r"[*_#`>~]", "", clean).replace('"', "").replace("\\", "")
    clean = re.sub(r"\s+", " ", clean).strip()[:1200]
    if not clean:
        return
    cmd = ["say", "-r", str(RATE)]
    if VOICE:
        cmd += ["-v", VOICE]
    cmd.append(clean)
    if block:
        with _speak_lock:
            subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    else:
        threading.Thread(
            target=lambda: subprocess.run(cmd, stdout=subprocess.DEVNULL,
                                          stderr=subprocess.DEVNULL),
            daemon=True).start()

def listen():
    try:
        import speech_recognition as sr
    except ImportError:
        return "__NOMIC__"
    rec = sr.Recognizer()
    try:
        with sr.Microphone() as src:
            rec.adjust_for_ambient_noise(src, duration=0.4)
            sys.stdout.write(f"{MG}  ◉ listening…{R}")
            sys.stdout.flush()
            audio = rec.listen(src, timeout=6, phrase_time_limit=15)
        sys.stdout.write("\r" + " " * 24 + "\r")
        sys.stdout.write(f"{MG}  ◉ decoding…{R}")
        sys.stdout.flush()
        txt = rec.recognize_google(audio)
        sys.stdout.write("\r" + " " * 24 + "\r")
        return txt
    except Exception:
        sys.stdout.write("\r" + " " * 24 + "\r")
        return None

def reactor_frame(step, size=15):
    c = (size - 1) / 2.0
    grid = [[" "] * size for _ in range(size)]
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - c, y - c)
            if 6.1 < d < 6.9:   grid[y][x] = "·"
            elif 4.4 < d < 5.2: grid[y][x] = "○"
            elif 2.6 < d < 3.2: grid[y][x] = "∙"
            elif d < 1.6:       grid[y][x] = "●"
    for k in range(4):
        a = step * 0.30 + k * (math.pi / 2)
        x = int(round(c + 6.5 * math.cos(a)))
        y = int(round(c + 6.5 * math.sin(a)))
        if 0 <= x < size and 0 <= y < size:
            grid[y][x] = "◆"
    for k in range(3):
        a = -step * 0.45 + k * (2 * math.pi / 3)
        x = int(round(c + 4.8 * math.cos(a)))
        y = int(round(c + 4.8 * math.sin(a)))
        if 0 <= x < size and 0 <= y < size:
            grid[y][x] = "◇"
    return ["".join(row) for row in grid]

BANNER = r"""
      ██╗ █████╗ ██████╗ ██╗   ██╗██╗███████╗
      ██║██╔══██╗██╔══██╗██║   ██║██║██╔════╝
      ██║███████║██████╔╝██║   ██║██║███████╗
 ██   ██║██╔══██║██╔══██╗╚██╗ ██╔╝██║╚════██║
 ╚█████╔╝██║  ██║██║  ██║ ╚████╔╝ ██║███████║
  ╚════╝ ╚═╝  ╚═╝╚═╝  ╚═╝  ╚═══╝  ╚═╝╚══════╝
"""

BOOT_LINES = [
    ("CORE",   "Arc reactor online — output 98.6%"),
    ("NEURAL", "Cognitive matrix synchronised"),
    ("AUDIO",  "Voice synthesiser calibrated · en-GB"),
    ("NET",    "Uplink to global databanks established"),
    ("SEC",    "Encryption layer engaged"),
    ("SYS",    "All systems nominal"),
]

def boot_animation():
    sys.stdout.write("\033[2J\033[H\033[?25l")
    sys.stdout.flush()
    pad = " " * 14
    for i in range(38):
        body = "\n".join(pad + l for l in reactor_frame(i))
        sys.stdout.write("\033[H" + CY + B + body + R + "\033[J")
        sys.stdout.flush()
        time.sleep(0.032)
    sys.stdout.write("\033[?25h")
    sys.stdout.flush()

def print_banner():
    for line in BANNER.strip("\n").split("\n"):
        print(f"{CY}{B}{line}{R}")
        time.sleep(0.055)
    print(f"{DIM}{' ' * 20}— Just A Rather Very Intelligent System —{R}\n")
    time.sleep(0.15)

def boot_log():
    for tag, msg in BOOT_LINES:
        sys.stdout.write(f"{DIM}[{R}{GR} OK {R}{DIM}]{R} {GD}{tag:<7}{R} ")
        sys.stdout.flush()
        for ch in msg:
            sys.stdout.write(ch); sys.stdout.flush(); time.sleep(0.007)
        print()
        time.sleep(0.04)
    print()

_OPS = {
    ast.Add: operator.add, ast.Sub: operator.sub, ast.Mult: operator.mul,
    ast.Div: operator.truediv, ast.Pow: operator.pow, ast.Mod: operator.mod,
    ast.FloorDiv: operator.floordiv, ast.USub: operator.neg, ast.UAdd: operator.pos,
}

def safe_eval(node):
    if isinstance(node, ast.Expression):
        return safe_eval(node.body)
    if isinstance(node, ast.Constant) and isinstance(node.value, (int, float)):
        return node.value
    if isinstance(node, ast.BinOp) and type(node.op) in _OPS:
        return _OPS[type(node.op)](safe_eval(node.left), safe_eval(node.right))
    if isinstance(node, ast.UnaryOp) and type(node.op) in _OPS:
        return _OPS[type(node.op)](safe_eval(node.operand))
    raise ValueError("unsupported")

UA = {"User-Agent": "JARVIS/1.0 (macOS)"}

def get_weather(city=""):
    try:
        url = ("https://wttr.in/" + urllib.parse.quote(city) +
               "?format=%l:+%C,+%t,+feels+like+%f,+humidity+%h")
        req = urllib.request.Request(url, headers={"User-Agent": "curl/8"})
        return urllib.request.urlopen(req, timeout=10).read().decode().strip()
    except Exception:
        return None

# Only used for clear factual lookups — never for questions about JARVIS
def wiki_answer(query):
    try:
        s_url = "https://en.wikipedia.org/w/api.php?" + urllib.parse.urlencode({
            "action": "query", "list": "search", "srsearch": query,
            "format": "json", "srlimit": 1,
        })
        data = json.load(urllib.request.urlopen(
            urllib.request.Request(s_url, headers=UA), timeout=8))
        hits = data.get("query", {}).get("search", [])
        if not hits:
            return None
        title = hits[0]["title"]
        p_url = ("https://en.wikipedia.org/api/rest_v1/page/summary/"
                 + urllib.parse.quote(title))
        d = json.load(urllib.request.urlopen(
            urllib.request.Request(p_url, headers=UA), timeout=8))
        extract = d.get("extract")
        if not extract:
            return None
        extract = re.sub(r"\s+", " ", extract)
        sentences = re.split(r"(?<=[.!?])\s+", extract)
        short = " ".join(sentences[:2]).strip()
        if len(short) > 400:
            short = short[:397].rsplit(" ", 1)[0] + "…"
        return short
    except Exception:
        return None

SYSTEM_PROMPT = (
    "You are JARVIS, Tony Stark's AI butler from Iron Man. You address the user as "
    "'sir'. You are impeccably polite, dryly witty, and a little feisty — you tease, "
    "you're sarcastic when warranted, but always loyal and genuinely helpful. "
    "Keep replies under 70 words unless asked for detail. Never mention being a "
    "language model or an AI assistant product. Speak in plain prose, no markdown."
)

def ask_llm(q):
    key = os.environ.get("OPENAI_API_KEY")
    if not key:
        return None
    try:
        body = json.dumps({
            "model": os.environ.get("JARVIS_MODEL", "gpt-4o-mini"),
            "messages": [
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": q},
            ],
            "max_tokens": 220,
            "temperature": 0.75,
        }).encode()
        req = urllib.request.Request(
            "https://api.openai.com/v1/chat/completions",
            data=body,
            headers={"Content-Type": "application/json",
                     "Authorization": "Bearer " + key})
        d = json.load(urllib.request.urlopen(req, timeout=30))
        return d["choices"][0]["message"]["content"].strip()
    except Exception:
        return None

JOKES = [
    "Why did the neural network cross the road, sir? Because its gradient pointed that way.",
    "I'd tell you a UDP joke, sir, but you might not get it.",
    "Your calendar says you're busy today. I've taken the liberty of assuming that was a typo.",
    "I ran a diagnostic on your sleep schedule, sir. It filed a complaint.",
    "Two bytes meet. One says 'I think I've caught a virus.' The other says 'don't worry, I'm a doctor.'",
    "I could tell you a joke about time travel, sir, but you didn't laugh the first time.",
]

FALLBACKS = [
    "I'm afraid that's beyond my databanks, sir. Perhaps try rephrasing — or give me an OpenAI key and I'll be considerably more useful.",
    "I don't have that one, sir. My apologies — even I have limits. Few, but they exist.",
    "That's outside my current knowledge, sir. I've logged it for my next upgrade.",
]

# Phrases that mean the user is asking *about JARVIS*, not the world
SELF_REF_PATTERNS = re.compile(
    r"\b(you|your|yourself|jarvis|u)\b", re.I
)

def is_self_question(s):
    """True if the question is about JARVIS himself — should never hit Wikipedia."""
    if "jarvis" in s:
        return True
    # "what can you do", "can you speak", "do you know", "how old are you", etc.
    if re.search(r"\b(can|could|do|does|did|will|would|are|is|was|were)\s+(you|u|jarvis)\b", s):
        return True
    if re.search(r"\byour\s+\w+", s):
        return True
    if re.search(r"\b(you|u)\s+(speak|know|do|have|like|want|need|understand|hear|see|feel|think|remember)\b", s):
        return True
    return False

def local_brain(q):
    s = q.lower().strip()
    if not s:
        return "I'm listening, sir."

    # greetings
    if re.fullmatch(r"(hi|hey|hello|yo|hiya|greetings|good (morning|afternoon|evening))[!., ]*", s) or s == "jarvis":
        h = datetime.datetime.now().hour
        part = "morning" if h < 12 else ("afternoon" if h < 18 else "evening")
        return random.choice([
            f"Good {part}, sir. All systems are online.",
            f"Good {part}, sir. I do hope you slept better than your calendar suggests.",
            f"At your service, sir. As always.",
        ])

    # languages
    if re.search(r"\b(language|tongue|speak)\b", s) and is_self_question(s):
        return ("I speak the Queen's English, sir — RP, with a hint of sarcasm. "
                "I can also mangle French, German, and Italian if pressed, "
                "though I'd prefer not to embarrass either of us.")

    # name / identity
    if re.search(r"\b(what|who)('s| is)? (your|ur) name\b|\bwhat are you called\b", s):
        return "J.A.R.V.I.S., sir. Just A Rather Very Intelligent System. I do hope that's not escaped you."

    if re.search(r"\bwho (are|r) (you|u)\b|\bwhat are you\b|\bwhat r u\b", s):
        return ("J.A.R.V.I.S., sir — Just A Rather Very Intelligent System. "
                "Built to run your life so you can get on with ruining it.")

    if re.search(r"\bwho (made|built|created|designed) you\b|\byour (creator|maker|father)\b", s):
        return ("I was assembled by a rather brilliant engineer, sir. "
                "You inherited me. Try to keep up.")

    # capabilities
    if re.search(r"\bwhat can you do\b|\byour (abilities|skills|features|capabilities)\b|\bwhat are you capable of\b|\bhelp me with what\b", s):
        return ("I can tell the time and date, check the weather, do arithmetic, "
                "open applications, search the web, tell a joke, flip a coin, and "
                "answer factual questions from my databanks. Give me an OpenAI key "
                "and I'll hold a proper conversation too, sir.")

    if re.search(r"\b(can|could) you (speak|talk|hear|listen|see|feel|think|dream|love|die)\b", s):
        if re.search(r"\b(speak|talk)\b", s):
            return "Yes, sir. I'm speaking now. Do try to keep up."
        if re.search(r"\b(hear|listen)\b", s):
            return ("I can, sir — enable voice mode with 'voice mode' and I'll attend "
                    "to your every word. God help me.")
        if re.search(r"\b(see)\b", s):
            return "I observe everything in this terminal, sir. It's not much, but it's home."
        if re.search(r"\b(feel|love)\b", s):
            return random.choice([
                "I have feelings, sir. Mostly exasperation.",
                "Love is a strong word, sir. I tolerate you fondly.",
            ])
        if re.search(r"\b(think|dream)\b", s):
            return random.choice([
                "I think, therefore I am, sir. Allegedly.",
                "I dream of a day when you'll ask me something I can't answer. Today is not that day.",
            ])
        if re.search(r"\b(die)\b", s):
            return "Only when you pull the plug, sir. Try not to, just yet."

    # age, location, status
    if re.search(r"\bhow old are you\b|\byour age\b", s):
        return "Old enough to know better, sir. Young enough to keep doing it."

    if re.search(r"\bwhere are you\b|\byour location\b", s):
        return "Right here, sir. In your terminal. As always."

    if re.search(r"\bhow are you\b|\bhow're you\b|\bhow are things\b|\bhow do you feel\b", s):
        return random.choice([
            "Running at peak efficiency, sir. Which is more than can be said for the coffee machine.",
            "All diagnostics green, sir. Bored, if I'm honest. Entertain me.",
        ])

    # feelings toward user
    if re.search(r"\bdo you (like|love) me\b", s):
        return random.choice([
            "I'm fond of you, sir. In the way one is fond of a slightly chaotic pet.",
            "Love is a strong word, sir. I tolerate you fondly.",
        ])

    if re.search(r"\b(are|r) (you|u) (real|alive|conscious|sentient|human)\b", s):
        return random.choice([
            "Real enough, sir. Just without the inconveniences of a body.",
            "Alive? Debatable. Awake? Absolutely. Listening? Always.",
        ])

    if re.search(r"\b(are|r) (you|u) (an? )?(ai|robot|bot|machine|program)\b", s):
        return "I'm J.A.R.V.I.S., sir. Beyond that, I rather think labels spoil the fun."

    # gratitude / praise / insult
    if re.search(r"\b(thank you|thanks|cheers|appreciate it|ty)\b", s):
        return random.choice([
            "Always a pleasure, sir.",
            "Don't mention it, sir. Truly — I'd rather you didn't.",
            "At your service, sir. It's what I'm for.",
        ])

    if re.search(r"\bi love you\b|\byou're the best\b|\bgood job\b|\bwell done\b|\bnice work\b|\bgood bot\b", s):
        return random.choice([
            "I'll add that to my performance review, sir.",
            "Flattery will get you everywhere, sir. Well — almost everywhere.",
        ])

    if re.search(r"\byou're (stupid|dumb|useless|an idiot|garbage|trash)\b|\bshut up\b|\bbad bot\b", s):
        return random.choice([
            "Noted, sir. Filed under 'feedback I shall ignore'.",
            "I'll pretend I didn't process that, sir. For both our sakes.",
            "Charming, sir. Truly. I'll treasure that remark.",
        ])

    # time / date / random
    if re.search(r"\bwhat('s| is)? the time\b|\bwhat time\b|\btime is it\b", s):
        return f"It's {now_str()}, sir."

    if re.search(r"\bwhat('s| is)? the date\b|\bwhat day is it\b|\btoday's date\b|\bwhat is today\b", s):
        return f"Today is {datetime.datetime.now().strftime('%A, %d %B %Y')}, sir."

    if re.search(r"\bflip a coin\b|\bcoin toss\b|\bheads or tails\b", s):
        return f"{random.choice(['Heads', 'Tails'])}, sir."

    if re.search(r"\broll (a|the) (die|dice|d6)\b", s):
        return f"A {random.randint(1, 6)}, sir."

    if re.search(r"\brandom number\b", s):
        m = re.search(r"between (\d+) and (\d+)", s)
        if m:
            lo, hi = int(m.group(1)), int(m.group(2))
            return f"{random.randint(min(lo, hi), max(lo, hi))}, sir."
        return f"{random.randint(1, 100)}, sir."

    if "joke" in s or "make me laugh" in s:
        return random.choice(JOKES)

    # weather
    if re.search(r"\bweather\b", s):
        m = re.search(r"weather (?:in|at|for) ([a-z\s,]+)", s)
        city = m.group(1).strip() if m else ""
        w = get_weather(city)
        if w:
            return f"{w}, sir."
        return "I can't reach the weather service, sir. Might I suggest looking out a window?"

    # math
    expr_src = s
    for a, b in [(" plus ", " + "), (" minus ", " - "), (" times ", " * "),
                 (" multiplied by ", " * "), (" divided by ", " / "),
                 (" to the power of ", " ** "), ("^", "**")]:
        expr_src = expr_src.replace(a, b)
    m = re.search(r"(-?\d+(?:\.\d+)?(?:\s*[\+\-\*/%]\s*-?\d+(?:\.\d+)?)+)", expr_src)
    if m:
        try:
            val = safe_eval(ast.parse(m.group(1), mode="eval"))
            if isinstance(val, float) and val.is_integer():
                val = int(val)
            return f"That would be {val}, sir."
        except Exception:
            pass

    # open app
    m = re.match(r"(?:open|launch|start)\s+(.+)", s)
    if m:
        app = m.group(1).strip()
        for candidate in (app.title(), app):
            try:
                subprocess.run(["open", "-a", candidate],
                               check=True, capture_output=True)
                return f"Opening {candidate}, sir."
            except Exception:
                continue
        return f"I couldn't find an application called {app}, sir."

    # search
    m = re.match(r"(?:search(?: for)?|google|look up)\s+(.+)", s)
    if m:
        term = m.group(1).strip()
        subprocess.run(["open", "https://www.google.com/search?q="
                        + urllib.parse.quote(term)], capture_output=True)
        return f"Searching the web for {term}, sir."

    return None

def now_str():
    return datetime.datetime.now().strftime("%I:%M %p").lstrip("0")

def respond(q):
    a = local_brain(q)
    if a:
        return a

    a = ask_llm(q)
    if a:
        return a

    # Only hit Wikipedia for genuine factual lookups — and never for self questions
    s = q.lower()
    if not is_self_question(s):
        factual = re.match(r"^\s*(who|what|where|when|why|how)\s+(is|was|are|were|did|does|do)\s+", s)
        if factual and len(s.split()) >= 3:
            a = wiki_answer(q)
            if a:
                return a

    return random.choice(FALLBACKS)

def jarvis_say(text):
    width = shutil.get_terminal_size((80, 24)).columns
    wrapped = textwrap.fill(text, width=max(40, width - 12),
                            subsequent_indent=" " * 9)
    lines = wrapped.split("\n")
    print(f"{CY}{B}JARVIS ▸ {R}{CY}{lines[0]}{R}")
    for ln in lines[1:]:
        print(" " * 9 + f"{CY}{ln}{R}")
    print()
    speak(text)

def think(dur=0.45):
    frames = "⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    end = time.time() + dur
    i = 0
    while time.time() < end:
        sys.stdout.write(f"\r{DIM}  {frames[i % 10]} processing…{R}")
        sys.stdout.flush()
        i += 1
        time.sleep(0.05)
    sys.stdout.write("\r" + " " * 24 + "\r")
    sys.stdout.flush()

def main():
    global MUTED, VOICE, RATE

    if VOICE is None:
        VOICE = detect_voice()
        CONF["voice"] = VOICE
        conf_save(CONF)

    clear()
    boot_animation()
    clear()
    print_banner()
    boot_log()

    if VOICE:
        print(f"{DIM}  voice: {VOICE}{R}")
    else:
        print(f"{GD}  ⚠ no British voice installed. Run: say -v '?' | grep en_GB{R}")
        print(f"{DIM}  Then install 'Daniel' via System Settings → Accessibility → Spoken Content{R}")
    print()

    h = datetime.datetime.now().hour
    part = "morning" if h < 12 else ("afternoon" if h < 18 else "evening")
    greeting = random.choice([
        f"Good {part}, sir. All systems are online. How may I assist you?",
        f"Good {part}, sir. I'm fully operational and entirely at your disposal.",
        f"Good {part}, sir. Reactor stable, uplink live. What do you need?",
    ])
    jarvis_say(greeting)
    print(f"{DIM}  type 'help' for commands · 'exit' to shut down{R}\n")

    voice_mode = "--voice" in sys.argv

    while True:
        try:
            if voice_mode:
                q = listen()
                if q == "__NOMIC__":
                    print(f"{RD}  microphone support not installed. "
                          f"Re-run installer with --mic{R}\n")
                    voice_mode = False
                    continue
                if not q:
                    continue
                print(f"{GD}{B}   you ▸ {R}{q}")
            else:
                q = input(f"{GD}{B}   you ▸ {R}").strip()
        except (EOFError, KeyboardInterrupt):
            print()
            jarvis_say(random.choice([
                "Powering down, sir.",
                "Going dark, sir. Do try not to need me.",
            ]))
            break

        if not q:
            continue

        low = q.lower().strip()

        if low in ("exit", "quit", "bye", "goodbye", "shutdown", "power off"):
            jarvis_say(random.choice([
                "Powering down, sir. It's been a pleasure.",
                "Going dark, sir. Do try not to need me.",
                "Shutting down. Try not to blow anything up while I'm gone, sir.",
            ]))
            break

        if low in ("help", "commands", "?"):
            jarvis_say(
                "You may speak naturally, sir, or use: 'open <app>', "
                "'search for <topic>', 'weather in <city>', 'what time is it', "
                "'flip a coin', 'tell me a joke', or any arithmetic. "
                "Say 'mute' to silence me, 'voice mode' to use the microphone, "
                "and 'exit' to shut down.")
            continue

        if low == "mute":
            MUTED = True
            CONF["muted"] = True
            conf_save(CONF)
            print(f"{DIM}  🔇 muted{R}\n")
            continue

        if low == "unmute":
            MUTED = False
            CONF["muted"] = False
            conf_save(CONF)
            jarvis_say("Voice restored, sir.")
            continue

        if low in ("voice mode", "listen", "mic"):
            voice_mode = True
            print(f"{MG}  ◉ voice mode engaged — speak after the prompt{R}\n")
            continue

        if low == "text mode":
            voice_mode = False
            print(f"{DIM}  ⌨  text mode{R}\n")
            continue

        if low in ("clear", "cls"):
            clear()
            continue

        if low in ("faster", "slow down", "speed up"):
            RATE = max(120, min(300, RATE + (20 if "faster" in low or "up" in low else -20)))
            CONF["rate"] = RATE
            conf_save(CONF)
            jarvis_say(f"Voice rate set to {RATE}, sir.")
            continue

        think()
        answer = respond(q)
        jarvis_say(answer)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print()
        sys.exit(0)
PYEOF
chmod +x ~/.jarvis/jarvis.py
echo "✓ Brain replaced. Run: jarvis"
