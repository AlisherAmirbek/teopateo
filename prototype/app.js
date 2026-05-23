const icons = {
  home: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="m3 11 9-8 9 8"/><path d="M5 10v10h14V10"/><path d="M9 20v-6h6v6"/></svg>`,
  plan: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M8 2v4"/><path d="M16 2v4"/><rect x="3" y="4" width="18" height="18" rx="3"/><path d="M3 10h18"/><path d="m9 16 2 2 4-5"/></svg>`,
  check: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6 9 17l-5-5"/></svg>`,
  insight: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 19V5"/><path d="M4 19h16"/><path d="M8 15v-4"/><path d="M12 15V7"/><path d="M16 15v-6"/></svg>`,
  coach: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15a4 4 0 0 1-4 4H8l-5 3V7a4 4 0 0 1 4-4h10a4 4 0 0 1 4 4z"/></svg>`,
  flame: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 22c4 0 7-3 7-7 0-3-1.5-5.2-3.7-7.5-.6 2.2-2 3.4-3.3 4.4.2-3.2-1.2-6.2-4.1-8.9C8.1 7.5 5 9.8 5 15c0 4 3 7 7 7Z"/></svg>`,
  close: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 6 6 18"/><path d="m6 6 12 12"/></svg>`,
  send: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="m22 2-7 20-4-9-9-4Z"/><path d="M22 2 11 13"/></svg>`,
  walk: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="13" cy="4" r="2"/><path d="M7 21 10 13l3 3v5"/><path d="M7 10l4-3 3 3 3 1"/></svg>`,
  water: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 22a7 7 0 0 0 7-7c0-4-7-13-7-13S5 11 5 15a7 7 0 0 0 7 7Z"/></svg>`,
  phone: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 16.9v3a2 2 0 0 1-2.2 2 19.8 19.8 0 0 1-8.6-3.1 19.5 19.5 0 0 1-6-6A19.8 19.8 0 0 1 2.1 4.2 2 2 0 0 1 4.1 2h3a2 2 0 0 1 2 1.7c.1 1 .4 1.9.7 2.8a2 2 0 0 1-.5 2.1L8.1 9.9a16 16 0 0 0 6 6l1.3-1.2a2 2 0 0 1 2.1-.5c.9.3 1.8.6 2.8.7a2 2 0 0 1 1.7 2Z"/></svg>`,
  bell: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.1" stroke-linecap="round" stroke-linejoin="round"><path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9"/><path d="M10 21h4"/></svg>`,
  plus: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round"><path d="M12 5v14"/><path d="M5 12h14"/></svg>`,
};

const state = {
  active: "dashboard",
  quitMode: "Taper",
  timerSeconds: 600,
  timerRunning: false,
  selectedTriggers: ["Coffee", "Work stress"],
  mood: 6,
  stress: 7,
  confidence: 5,
  smokedToday: null,
  toast: "",
  coachMessages: [
    { role: "bot", text: "You usually get hit hardest after work. Want to plan the first 20 minutes after you leave?" },
  ],
};

const tabs = [
  ["dashboard", "Today", icons.home],
  ["plan", "Plan", icons.plan],
  ["checkin", "Check-in", icons.check],
  ["insights", "Insights", icons.insight],
  ["coach", "Coach", icons.coach],
];

let timerHandle = null;

function setActive(screen) {
  state.active = screen;
  render();
}

function showToast(text) {
  state.toast = text;
  render();
  setTimeout(() => {
    state.toast = "";
    render();
  }, 1800);
}

function toggleTimer() {
  state.timerRunning = !state.timerRunning;
  if (state.timerRunning) {
    timerHandle = setInterval(() => {
      state.timerSeconds = Math.max(0, state.timerSeconds - 1);
      if (state.timerSeconds === 0) {
        clearInterval(timerHandle);
        state.timerRunning = false;
      }
      render();
    }, 1000);
  } else {
    clearInterval(timerHandle);
  }
  render();
}

function resetTimer() {
  clearInterval(timerHandle);
  state.timerRunning = false;
  state.timerSeconds = 600;
  render();
}

function fmt(seconds) {
  const mins = String(Math.floor(seconds / 60)).padStart(2, "0");
  const secs = String(seconds % 60).padStart(2, "0");
  return `${mins}:${secs}`;
}

function toggleTrigger(trigger) {
  if (state.selectedTriggers.includes(trigger)) {
    state.selectedTriggers = state.selectedTriggers.filter((item) => item !== trigger);
  } else {
    state.selectedTriggers = [...state.selectedTriggers, trigger];
  }
  render();
}

function saveCheckin() {
  const status = state.smokedToday === true ? "Slip logged. The plan stays active." : "Check-in saved.";
  showToast(status);
}

function sendCoachMessage() {
  const input = document.querySelector("#coachInput");
  const value = input?.value.trim();
  if (!value) return;
  state.coachMessages.push({ role: "user", text: value });
  state.coachMessages.push({
    role: "bot",
    text: "Let us turn that into a specific rule: name the trigger, choose a 10-minute replacement, then decide who gets the alert if it spikes.",
  });
  render();
}

function renderDashboard() {
  return `
    <div class="screen home-screen">
      <header class="home-header">
        <span>TeoPateo</span>
        <button class="home-bell" aria-label="Notifications">${icons.bell}</button>
      </header>

      <section class="mascot-stage" aria-label="TeoPateo companion">
        <img class="top-mascot" src="../images/mascot.png" alt="TeoPateo mascot" />
      </section>

      <section class="home-copy">
        <h1>Pause before the cigarette.</h1>
        <p>Your 10-minute rescue plan is ready when the urge shows up.</p>
      </section>

      <button class="home-rescue" onclick="setActive('craving')">
        <span>I want to smoke</span>
        <strong>Start rescue</strong>
      </button>

      <section class="home-facts" aria-label="Today's quit progress">
        <div><span>Smoke-free</span><strong>4 days</strong></div>
        <div><span>Next risk</span><strong>9:00 PM</strong></div>
      </section>
    </div>
  `;
}

function renderPlan() {
  const rules = [
    ["After coffee", "Drink water first, wait 10 minutes, log the urge."],
    ["Leaving work", "Walk one block before checking messages."],
    ["Alcohol", "Use a support contact before the first drink."],
    ["After meals", "Brush teeth or chew gum immediately."],
  ];

  return `
    <div class="screen">
      <header class="topbar">
        <div>
          <p class="eyeline">Quit plan</p>
          <h1>Your plan stays specific.</h1>
        </div>
        <img class="avatar" src="../images/icon.png" alt="TeoPateo icon" />
      </header>

      <section class="panel">
        <div class="plan-date">
          <div class="date-tile"><div><span>JUN</span><strong>01</strong></div></div>
          <div>
            <h2>Quit date</h2>
            <p>11 days away. The app will increase reminders during your highest-risk windows.</p>
          </div>
        </div>
      </section>

      <section class="panel">
        <h2>Approach</h2>
        <div class="segmented">
          ${["Taper", "Cold turkey"].map((mode) => `
            <button class="${state.quitMode === mode ? "is-active" : ""}" onclick="state.quitMode='${mode}'; render()">${mode}</button>
          `).join("")}
        </div>
        <p>${state.quitMode === "Taper" ? "Reduce by two cigarettes every three days until quit date." : "Prepare substitutes and support alerts before quit date."}</p>
      </section>

      <section class="panel">
        <div class="section-title">
          <h2>When this happens</h2>
          <button class="text-button" onclick="showToast('New rule draft added')">Add rule</button>
        </div>
        ${rules.map(([trigger, action]) => `
          <div class="rule-row">
            <div>
              <strong>${trigger}</strong>
              <span>${action}</span>
            </div>
            <button class="switch" aria-label="Rule enabled"><span></span></button>
          </div>
        `).join("")}
      </section>

      <section class="panel">
        <h2>Support circle</h2>
        <div class="list">
          <div class="list-row"><span class="row-icon">${icons.phone}</span><div><strong>Maya</strong><span>Craving alert and evening check-in</span></div><span class="badge">Text</span></div>
          <div class="list-row"><span class="row-icon">${icons.phone}</span><div><strong>1-800-QUIT-NOW</strong><span>US quitline support</span></div><span class="badge">Call</span></div>
        </div>
      </section>

    </div>
  `;
}

function renderCraving() {
  const progress = `${((600 - state.timerSeconds) / 600) * 100}%`;
  const triggers = ["Coffee", "Work stress", "After meal", "Boredom", "Alcohol", "Social", "Driving", "Anxiety"];
  return `
    <div class="screen">
      <header class="emergency-header">
        <div>
          <p class="eyeline">Craving mode</p>
          <h1>Ride out the next 10 minutes.</h1>
        </div>
        <button class="quiet-button" onclick="resetTimer(); setActive('dashboard')" aria-label="Close craving mode">${icons.close}</button>
      </header>

      <section class="panel timer-panel">
        <div class="timer" style="--progress:${progress}">
          <div class="timer-core">
            <div>
              <strong>${fmt(state.timerSeconds)}</strong>
              <span>${state.timerRunning ? "Running" : "Ready"}</span>
            </div>
          </div>
        </div>
        <div class="button-row">
          <button class="primary" onclick="toggleTimer()">${state.timerRunning ? "Pause" : "Start timer"}</button>
          <button class="secondary" onclick="resetTimer()">Reset</button>
        </div>
      </section>

      <section class="panel">
        <h2>Breathe</h2>
        <div class="breath-orb" aria-hidden="true"></div>
        <p>Inhale slowly. Hold. Exhale longer than you inhaled.</p>
      </section>

      <section class="panel">
        <h2>Your reason</h2>
        <p>I want mornings without chest tightness, and I want to keep promises I made when I was calm.</p>
      </section>

      <section class="panel">
        <h2>Do one instead</h2>
        <div class="list">
          <div class="list-row"><span class="row-icon">${icons.water}</span><div><strong>Drink cold water</strong><span>Finish one full glass before deciding anything.</span></div><span class="badge">2m</span></div>
          <div class="list-row"><span class="row-icon">${icons.walk}</span><div><strong>Walk outside</strong><span>Move until the timer drops below 6:00.</span></div><span class="badge">4m</span></div>
          <div class="list-row"><span class="row-icon">${icons.phone}</span><div><strong>Text Maya</strong><span>Send the preset craving alert.</span></div><span class="badge">Now</span></div>
        </div>
      </section>

      <section class="panel">
        <h2>Log the trigger</h2>
        <div class="chip-row">
          ${triggers.map((trigger) => `
            <button class="chip ${state.selectedTriggers.includes(trigger) ? "is-selected" : ""}" onclick="toggleTrigger('${trigger}')">${trigger}</button>
          `).join("")}
        </div>
      </section>

      <button class="primary" onclick="showToast('Craving logged. Plan updated.'); resetTimer(); setActive('dashboard')">I got through it</button>
    </div>
  `;
}

function renderCheckin() {
  return `
    <div class="screen">
      <header class="topbar">
        <div>
          <p class="eyeline">Daily check-in</p>
          <h1>Record today without judging it.</h1>
        </div>
      </header>

      <section class="panel">
        <div class="form-group">
          <label for="mood">Mood</label>
          <div class="slider-row">
            <input id="mood" type="range" min="1" max="10" value="${state.mood}" oninput="state.mood=this.value; render()" />
            <span class="score">${state.mood}</span>
          </div>
        </div>
        <div class="form-group">
          <label for="stress">Stress</label>
          <div class="slider-row">
            <input id="stress" type="range" min="1" max="10" value="${state.stress}" oninput="state.stress=this.value; render()" />
            <span class="score">${state.stress}</span>
          </div>
        </div>
        <div class="form-group">
          <label for="confidence">Confidence</label>
          <div class="slider-row">
            <input id="confidence" type="range" min="1" max="10" value="${state.confidence}" oninput="state.confidence=this.value; render()" />
            <span class="score">${state.confidence}</span>
          </div>
        </div>
      </section>

      <section class="panel">
        <h2>Did you smoke today?</h2>
        <div class="button-row">
          <button class="secondary" onclick="state.smokedToday=false; render()">No smoke</button>
          <button class="danger" onclick="state.smokedToday=true; render()">I smoked</button>
        </div>
      </section>

      ${state.smokedToday === true ? `
        <section class="panel">
          <h2>Slip recovery</h2>
          <p>This stays part of the same quit attempt. Capture what happened and adjust the plan.</p>
          <div class="form-group">
            <label for="slipNote">What led to it?</label>
            <textarea id="slipNote">I left work stressed and bought cigarettes before dinner.</textarea>
          </div>
          <div class="chip-row">
            <button class="chip is-selected">Work stress</button>
            <button class="chip amber">Evening</button>
            <button class="chip blue">Driving</button>
          </div>
        </section>
      ` : ""}

      <button class="primary" onclick="saveCheckin()">Save check-in</button>
    </div>
  `;
}

function renderInsights() {
  const levels = [1, 1, 2, 2, 1, 2, 3, 1, 2, 2, 3, 4, 3, 2, 1, 1, 2, 4, 4, 3, 2, 1, 2, 3, 4, 3, 2, 1];
  return `
    <div class="screen">
      <header class="topbar">
        <div>
          <p class="eyeline">Pattern insights</p>
          <h1>Your risk is predictable.</h1>
        </div>
      </header>

      <section class="panel insight-callout">
        <h2>Top pattern</h2>
        <p>Your highest-risk window is 9:00-10:30 PM. It accounts for 38% of logged cravings.</p>
      </section>

      <section class="panel">
        <h2>Trigger contribution</h2>
        <div class="timeline">
          <div class="timeline-row"><span>Coffee</span><div class="bar amber"><span style="width:42%"></span></div><strong>42%</strong></div>
          <div class="timeline-row"><span>Stress</span><div class="bar amber"><span style="width:36%"></span></div><strong>36%</strong></div>
          <div class="timeline-row"><span>Meals</span><div class="bar"><span style="width:24%"></span></div><strong>24%</strong></div>
          <div class="timeline-row"><span>Social</span><div class="bar"><span style="width:18%"></span></div><strong>18%</strong></div>
        </div>
      </section>

      <section class="panel">
        <h2>Craving heat</h2>
        <div class="heatmap" aria-label="Craving heat map">
          ${levels.map((level) => `<span class="heat" data-level="${level}"></span>`).join("")}
        </div>
      </section>

      <section class="panel">
        <h2>Plan adjustment</h2>
        <p>Add a hard rule for leaving work: walk one block before entering a store or opening delivery apps.</p>
        <button class="secondary" onclick="showToast('Rule added to quit plan')">Add to plan</button>
      </section>
    </div>
  `;
}

function renderCoach() {
  return `
    <div class="screen">
      <header class="topbar">
        <div>
          <p class="eyeline">AI coach</p>
          <h1>Ask for the next move.</h1>
        </div>
      </header>

      <section class="coach-log">
        ${state.coachMessages.map((message) => `<div class="message ${message.role}">${message.text}</div>`).join("")}
      </section>

      <section class="panel">
        <h2>Quick prompts</h2>
        <div class="chip-row">
          <button class="chip" onclick="state.coachMessages.push({role:'user', text:'Why do I smoke after work?'}); state.coachMessages.push({role:'bot', text:'After work combines stress, transition, and easy access. Your strongest move is to change the first 10 minutes, not the whole evening.'}); render()">After work</button>
          <button class="chip blue" onclick="state.coachMessages.push({role:'user', text:'Give me a craving script.'}); state.coachMessages.push({role:'bot', text:'Say this: I do not need to solve the whole quit attempt right now. I only need to pass this urge.'}); render()">Craving script</button>
          <button class="chip amber" onclick="state.coachMessages.push({role:'user', text:'I slipped today.'}); state.coachMessages.push({role:'bot', text:'Log the trigger and keep the attempt alive. One cigarette is data. The next decision still counts.'}); render()">Slip recovery</button>
        </div>
      </section>

      <div class="coach-input">
        <input id="coachInput" type="text" placeholder="Type what is happening..." onkeydown="if(event.key==='Enter') sendCoachMessage()" />
        <button onclick="sendCoachMessage()" aria-label="Send message">${icons.send}</button>
      </div>
    </div>
  `;
}

function renderNav() {
  return `
    <nav class="bottom-nav" aria-label="Prototype navigation">
      ${tabs.map(([key, label, icon]) => `
        <button class="nav-item ${state.active === key ? "is-active" : ""}" onclick="setActive('${key}')">
          ${icon}
          <span>${label}</span>
        </button>
      `).join("")}
    </nav>
  `;
}

function render() {
  const app = document.querySelector("#app");
  const screens = {
    dashboard: renderDashboard,
    plan: renderPlan,
    craving: renderCraving,
    checkin: renderCheckin,
    insights: renderInsights,
    coach: renderCoach,
  };

  app.innerHTML = `
    ${screens[state.active]()}
    ${state.active === "craving" ? "" : renderNav()}
    ${state.toast ? `<div class="toast">${state.toast}</div>` : ""}
  `;
}

render();
