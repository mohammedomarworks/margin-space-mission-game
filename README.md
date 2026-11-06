# MARGIN — THE SPACE MISSION DESIGN GAME
### *Every Gram. Every Watt. Every Decision.*

**MARGIN** is a 3D interactive aerospace engineering and mission management simulation built in Godot Engine 4.7. Designed in the spirit of the NASA Space Mission Design Game challenge, MARGIN puts players in command of designing, launching, operating, and debriefing an authentic Discovery-class lunar orbital survey mission.

Unlike generic arcade flight games or static web dashboards, MARGIN simulates real mission trade-offs, Tsiolkovsky orbital mechanics, epithermal neutron moderation astrophysics, solar array geometry, battery Depth-of-Discharge (DoD) during lunar orbital eclipses, and Deep Space Network (DSN) telemetry link margins.

---

## 🚀 Key Gameplay Stages

### 1. Flight Readiness Dossier (Mission Briefing)
- **Scenario:** Discovery-Class Lunar South Pole Volatile Survey (LSP-01).
- **Core Challenge:** Map cold-trap craters (Shackleton, Shoemaker, Faustini, Cabeus, Amundsen, Haworth) for volatile hydrogen enhancements.
- **Constraints:** Strict \$180.0M scenario budget cap, 380.0 kg launch envelope, and 365-day mission lifetime.

### 2. 3D Spacecraft Workshop
- **Subsystems (9 Categories, 27 Authentic Components):**
  - **Structure:** Modular Aluminum 6061 Monocoque, Carbon-Fiber Honeycomb Core, 3D-Printed Titanium Isogrid.
  - **Power:** Dual Deployable GaAs Triple-Junction Arrays, Body-Mounted Silicon Arrays, Ultra-Flex High-Efficiency Wings.
  - **Energy Storage:** Commercial Li-ion Battery, Space-Grade LiFePO4 Pack, Solid-State High-Capacity Array.
  - **Thermal Control:** Passive MLI Blankets, Heat Pipes & Active Louvers, Redundant Heaters & RTD Loop.
  - **Propulsion:** Cold Gas RCS Thrusters, Hydrazine Monopropellant System, Dual-Mode Chemical Bipropellant System, 25 mN Hall-Effect Electric Propulsion.
  - **Attitude Determination & Control (ADCS):** Reaction Wheels & Star Trackers, Cold Gas Reaction Control, 3-Axis Magnetorquer & Sun Sensor Array.
  - **Communications:** Patch Antenna & S-Band Transponder, Medium-Gain Horn & X-Band Transponder, High-Gain Parabolic Reflector (Ka/X Band).
  - **Command & Data Handling (C&DH):** Radiation-Tolerant Rad750, Fault-Tolerant Dual-LEON3 Computer, High-Reliability Triple-Modular Core.
  - **Scientific Payload:** Helium-3 Proportional-Counter Neutron Spectrometer (LP-NS Heritage), Lunar Exploration Neutron Detector (LRO LEND Heritage), Mini-RF Synthetic Aperture Radar.
- **Live 6-Resource Telemetry Gauges:** Launch Mass, Power Balance (sunlight surplus + battery eclipse DoD), Mission Budget, Data Storage Buffer, Comms Link Margin, and Orbit Lifetime.
- **Signature Feature — Trade-Off Echo:** Real-time engineering feedback explaining the aerospace ripple effect of every hardware decision.

### 3. Orbit & Launch Planning
- **Selectable Translunar Transfer Strategies:**
  - **Low-Energy Ballistic Transfer (WSB/BLT):** Fuel-efficient 83.7-day Weak Stability Boundary transit via Sun-Earth-Moon gravitational three-body interactions (citing 669.543 m/s Lunar Orbit Insertion retro-burn from JPL Monograph Series 12).
  - **Direct Conventional Transfer:** Fast 4.0-day translunar transit (citing 839.878 m/s impulsive LOI retro-burn from JPL Monograph Series 12).
- **Authoritative Educational Launch Vehicle Profiles:**
  - **Small Commercial Rideshare:** \$14.0M (260 kg TLI cap, 95.0% reliability).
  - **Medium Commercial EELV-Class:** \$32.0M (450 kg TLI cap, 98.5% reliability).
  - **Heavy Dedicated Booster:** \$65.0M (850 kg TLI cap, 99.5% reliability).
- **Automated Pre-Flight Gatekeeper:** Strictly validates launch vehicle payload capacity, fairing volume, fairing envelope dimensions, impulsive Delta-V requirements, and total mission budget.

### 4. Mission Operations (12-Month Flight Campaign)
- **Step-by-Step Lunar Operations:** Advance month-by-month through 12 dynamic operational cycles over 365 mission days.
- **Dynamic Orbital Events:** Solar Proton Events (SPE), DSN ground station maintenance outages, micrometeoroid impacts, thermal anomalies, and shadow cone eclipses.
- **Operational Flight Modes:** Nominal Routine Survey, High-Resolution Mapping (+50% science, +35% power load), Power Conservation (-35% load), and Comms Link Priority (+60% downlink bandwidth).
- **Volatile Mapping:** Target south polar craters to gather epithermal neutron flux depressions and build high-resolution regolith hydrogen matrices.

### 5. Mission Debrief & 8-Pillar Evaluation
- **Comprehensive Scorecard (100% Deterministic, Weighted 0–100):**
  1. **Scientific Achievement (25%):** Crater survey completeness, spatial resolution, and proxy verification.
  2. **Power & Eclipse Performance (15%):** Sunlight electrical surplus, peak battery DoD during 48-minute orbital eclipses, and blackout prevention.
  3. **Budget Efficiency (10%):** Spacecraft development cost + launch vehicle procurement + 12-month flight operations expenditure vs. \$180.0M scenario cap.
  4. **Mass & Volume Efficiency (10%):** Structural mass margin and payload volume packing density.
  5. **Data Storage Management (10%):** Onboard recorder buffer utilization and zero overflow science loss.
  6. **Communications Throughput (10%):** Cumulative downlinked gigabits and RF link margin closure (+8.2 dB over DSN 34m/70m).
  7. **Mission Lifetime & Schedule (10%):** Survival across 365 operational flight days.
  8. **System Reliability & Health (10%):** 50% pre-launch composite hardware reliability + 50% end-of-mission subsystem health.
- **Debrief Dossier Tabs:** Overview & Scorecard, Scientific Report & Craters, Engineering Decision Audit, 12-Month Interactive Timeline, Team Contributions, and Saved Designs Library.
- **Persistent Storage & Side-by-Side Comparison:** Save mission reports to browser local storage (IndexedDB `/userfs`), perform mathematical differential comparisons between designs, and delete obsolete runs.

---

## 🛠️ Technology Stack

- **Game Engine:** [Godot Engine 4.7.2 (Stable Official)](https://godotengine.org)
- **Renderer:** GL Compatibility (WebGL 2.0 / OpenGL ES 3.0) for universal browser and mobile compatibility.
- **Physics Engine:** Jolt Physics 3D.
- **Web Export:** Single-threaded WebAssembly (WASM) with Emscripten IDBFS persistence.
- **Branded Web Shell:** Custom aerospace loading screen with real-time asset streaming progress (downloaded MB / total MB / percentage) and radar status animations.
- **Hosting / Cloud Deployment:** Vercel Static Hosting (`build/web`) optimized for single-threaded Godot Web exports with `application/wasm` MIME configuration and instant revalidation headers.

---

## 📚 Scientific References & Heritage

MARGIN is grounded in published planetary science and aerospace literature:

1. **Lunar Prospector Neutron Spectrometer (LP-NS, 1998):**
   - Feldman, W. C., et al. (1998). *Fluxes of Fast and Epithermal Neutrons from Lunar Prospector: Evidence for Water Ice at the Lunar Poles*. Science, 281(5382), 1496–1500.
   - Utilized a helium-3 proportional-counter neutron spectrometer to detect epithermal neutron flux depressions caused by hydrogen moderation in polar regolith.
2. **Lunar Reconnaissance Orbiter (LRO LEND & Mini-RF, 2009):**
   - Mitrofanov, I. G., et al. (2010). *Hydrogen Mapping of the Lunar South Pole Using the LRO Lunar Exploration Neutron Detector (LEND)*. Science, 330(6003), 483–486.
   - Raney, R. K., et al. (2011). *The Lunar Mini-RF Radar: Dual-Polarized Synthetic Aperture Radar Observations*. JGR Planets.
3. **NASA/JPL Lunar Trajectory Reference:**
   - Parker, J. S., & Anderson, R. O. (2014). *Low-Energy Lunar Trajectory Design*. JPL Deep-Space Communications and Navigation Series (Monograph 12), California Institute of Technology / NASA JPL.
   - Reference cases cited: 4.036-day direct transfer (839.878 m/s LOI) and 83.706-day ballistic lunar transfer (669.543 m/s LOI) into low polar lunar orbit.
4. **LCROSS Lunar Crater Observation and Sensing Satellite (2009):**
   - Colaprete, A., et al. (2010). *Detection of Water in the Cabeus Crater Centaur Plume*. Science, 330(6003), 463–468.

---

## ⚠️ Educational Simulation Disclaimer

*MARGIN is an independent educational simulation created for academic, design, and simulation demonstration purposes. It is not affiliated with, endorsed by, or sponsored by NASA, the Jet Propulsion Laboratory (JPL), the European Space Agency (ESA), or any commercial aerospace launch provider.*

*All launch vehicle costs (\$14.0M, \$32.0M, \$65.0M) and operational budgets are illustrative educational models. Hydrogen enhancement detected via neutron flux moderation is modeled strictly as a scientific proxy for volatile concentration and does not constitute definitive proof of surface water ice at every surveyed crater.*

---

## 💻 Running the Game Locally

### Option A: Via Python Web Server (Recommended for Web Build)

1. Navigate to the project root:
   ```bash
   cd /Users/omar/godot-practice
   ```
2. Start an HTTP server serving the Web export:
   ```bash
   python3 -m http.server 8000 --directory build/web
   ```
3. Open your browser to:
   ```
   http://localhost:8000
   ```

### Option B: Native Desktop Execution via Godot Engine

Run the game directly with Godot Engine 4.7:
```bash
/Users/omar/Downloads/Godot.app/Contents/MacOS/Godot --path /Users/omar/godot-practice
```

### Option C: Running the Automated Quality Assurance Test Suites

Run each automated test suite headless:
```bash
# 1. Maneuver & Transfer Strategy Audit (15 tests)
Godot --headless --path . -s res://margin/tests/test_maneuver_audit.gd

# 2. Mission Operations Simulation Suite (13 tests)
Godot --headless --path . -s res://margin/tests/test_mission_operations.gd

# 3. Mission Debrief & 8-Pillar Scoring Suite (21 tests)
Godot --headless --path . -s res://margin/tests/test_mission_debrief.gd

# 4. Full End-to-End Gameplay Integration Suite (15 tests)
Godot --headless --path . -s res://margin/tests/test_end_to_end.gd

# 5. Full Browser Headless Chrome QA (Interactive Canvas, IndexedDB Persistence, WebGL)
node margin/tests/run_full_browser_qa.js
```

---

## 🌐 Deploying to Vercel

The project includes a ready-to-deploy `vercel.json` configured for Godot 4 Web exports with optimized HTTP headers:

1. Install Vercel CLI (if not already installed):
   ```bash
   npm i -g vercel
   ```
2. Export the latest Web build (or use pre-built `build/web`):
   ```bash
   /Users/omar/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/omar/godot-practice --export-release "Web" build/web/index.html
   ```
3. Deploy to production:
   ```bash
   vercel --prod
   ```
   *Vercel automatically detects `build/web` from `vercel.json` and deploys the static files with custom headers for WebAssembly MIME types (`application/wasm`) and instant revalidation.*

---

## 📂 Project Directory Structure

```
godot-practice/
├── margin/                          # MARGIN Core Game Module
│   ├── data/                        # Flight Databases & Data Models
│   │   ├── component_data.gd        # 27 Components across 9 Subsystems
│   │   ├── launch_vehicle_data.gd   # Authoritative Educational Launch Vehicle Database
│   │   ├── mission_data.gd          # Mission LSP-01 Constants & Constraints
│   │   ├── mission_evaluation_data.gd # Evaluation Storage & Local Comparison
│   │   ├── mission_operations_data.gd # 12 Monthly Windows, Events & Craters
│   │   ├── orbit_data.gd            # Orbit Profiles & Stationkeeping
│   │   └── transfer_data.gd         # Direct vs. Low-Energy BLT Transfers
│   ├── scenes/                      # 3D Scenes & User Interfaces
│   │   ├── main_menu.tscn           # Title Screen & 3D Celestial Environment
│   │   ├── mission_briefing.tscn    # Flight Readiness Dossier
│   │   ├── workshop.tscn            # 3D Craft Workshop & 6 Live Margins
│   │   ├── launch_planning.tscn     # Trajectory Planning & Pre-Flight Checks
│   │   ├── mission_operations.tscn  # 12-Month Flight Command Center
│   │   └── mission_debrief.tscn     # 8-Pillar Scorecard & Saved Comparisons
│   ├── scripts/                     # Gameplay Controllers & Physics Engines
│   │   ├── main_menu_controller.gd
│   │   ├── mission_briefing_controller.gd
│   │   ├── workshop_controller.gd
│   │   ├── launch_planner.gd
│   │   ├── mission_simulator.gd     # Deterministic Flight Simulation Engine
│   │   ├── mission_operations_controller.gd
│   │   ├── scoring_engine.gd        # 8-Pillar Evaluation Math (100% Deterministic)
│   │   ├── mission_debrief_controller.gd
│   │   ├── spacecraft_state.gd      # Craft Configuration & Telemetry State
│   │   ├── spacecraft_3d.gd         # Modular 3D Spacecraft Mesh Generator
│   │   └── orbit_camera.gd          # Smooth 3D Orbit Camera Controller
│   ├── tests/                       # Automated Verification Suites
│   │   ├── test_maneuver_audit.gd   # Maneuvers & Propulsion Limits (15/15 PASS)
│   │   ├── test_mission_operations.gd # Operations Flight Dynamics (13/13 PASS)
│   │   ├── test_mission_debrief.gd  # 8 Pillars & Scorecard Math (21/21 PASS)
│   │   ├── test_end_to_end.gd       # Complete Gameplay Integration (15/15 PASS)
│   │   └── run_full_browser_qa.js   # Full Browser UI & IndexedDB CDP Test
│   ├── ui/                          # Aerospace Dark Theme & Styling
│   └── web/                         # Branded HTML Shell with Progress Bar
├── build/
│   └── web/                         # Static Production Web Export
│       ├── index.html               # Custom Branded Shell with Real-Time Progress
│       ├── index.js                 # Godot Engine JavaScript Bridge
│       ├── index.wasm               # 39.5 MB Single-Threaded WASM Binary
│       └── index.pck                # 425 KB Virtual Flight Package
├── crystal_dash/                    # Original Practice Game (Preserved Intact)
├── vercel.json                      # Vercel Deployment Configuration
├── project.godot                    # Godot Engine Project Definition
└── README.md                        # Production Documentation
```

---
*Developed with Godot Engine 4.7 for the Space Mission Design Game challenge.*
