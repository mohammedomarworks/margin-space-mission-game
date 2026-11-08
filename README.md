# MARGIN — THE SPACE MISSION DESIGN GAME
### *Every Gram. Every Watt. Every Decision.*

**MARGIN** is a 3D interactive aerospace engineering and mission management simulation built in Godot Engine 4.7. Designed in the spirit of the NASA Space Mission Design Game challenge, MARGIN puts players in command of designing, launching, operating, and debriefing an authentic Discovery-class lunar orbital survey mission.

Unlike generic arcade flight games or static web dashboards, MARGIN simulates real mission trade-offs, Tsiolkovsky orbital mechanics, epithermal neutron moderation astrophysics, solar array geometry, battery Depth-of-Discharge (DoD) during lunar orbital eclipses, and Deep Space Network (DSN) telemetry link margins.

---

## 🚀 Key Gameplay Modes & Scenarios

MARGIN features multiple operational mission scenarios, interactive emergency decision branches, a local cooperative team mode, an unrestricted engineering sandbox, and a 3D surface exploration mode.

### 1. Mission Scenarios

#### Scenario A: Discovery-Class Lunar South Pole Volatile Survey (LSP-01)
- **Target Orbit:** Low Lunar Polar Orbit (100 km circular, 90° inclination).
- **Core Objective:** Map permanently shadowed craters (Shackleton, Shoemaker, Faustini, Cabeus, Amundsen, Haworth) for epithermal neutron flux depressions indicating hydrogen volatile enrichment.
- **Mission Constraints:** Strict \$180.0M budget cap, 380.0 kg launch envelope, 365-day mission lifetime.
- **Success Criteria:** Minimum 60.0/100 composite score on the 8-pillar rubric.

#### Scenario B: Earth Climate Sentinel (ECS-01)
- **Target Orbit:** Sun-Synchronous Orbit (selected educational reference orbit: 705 km polar SSO, 98.2° inclination, 10:30 AM descending node; modeled on the Landsat/EOS morning constellation, not a universal requirement for all Earth observation missions).
- **Core Objective:** Monitor 6 critical planetary sentinels across the Earth system:
  1. *Greenland Ice Sheet (Summit):* 3,200m Ice Elevation / Melt Albedo.
  2. *Antarctic Peninsula (Larsen C):* Ice Shelf Freeboard / Calving Flux.
  3. *Amazon Basin Carbon Sink:* Vegetation Index (NDVI) / CO2 Column.
  4. *Sahel Desertification Boundary:* Soil Moisture & Aridity Gradient.
  5. *North Atlantic Surface Indicators for AMOC Research:* Monitors sea surface temperature anomalies and ocean surface roughness. (Note: The mission does not model a dedicated microwave ocean radar altimeter for direct steric dynamic-height measurements; orbital optical and SAR surface observations provide indirect indicators or proxies, but cannot directly measure full-depth Atlantic Meridional Overturning Circulation (AMOC) volume transport, which requires sustained deep-water in-situ mooring networks such as RAPID/OSNAP and numerical ocean modeling).
  6. *Siberian Tundra Permafrost:* Atmospheric Methane (XCH4) Column.
- **Dedicated Earth Observation Payloads:**
  - *Multispectral Climate Radiometer:* 12-band VIS/NIR/SWIR pushbroom radiometer for cryospheric albedo, vegetation indices, and sea surface skin temperature (32 kg, 52W, \$24.0M).
  - *GHG Imaging Spectrometer:* High-resolution diffraction grating spectrometer for CO2 and CH4 column plumes (44 kg, 78W, \$36.0M).
  - *Ku-band SAR Interferometric Cryosphere Altimeter (CryoSat-2 SIRAL-inspired):* Ku-band SAR interferometric radar altimeter for polar ice sheet elevation changes and sea ice freeboard thickness (58 kg, 135W, \$42.0M educational gameplay estimates). Note: Modeled on CryoSat-2 SIRAL's ice-focused SAR/interferometric altimetry heritage; it is not a polarimetric SAR and does not model a dedicated microwave ocean radar altimeter for dynamic sea-surface height or full-depth AMOC transport.
- **Mission Constraints:** \$140.0M scenario budget cap, 550.0 kg launch envelope, 75.0-point composite success threshold.
- **Dedicated Polar Launch Vehicles:** Polar Small Rideshare (380 kg SSO cap, \$12.0M), Sun-Sync Medium Booster (720 kg SSO cap, \$26.0M), Polar Heavy Dedicated (1400 kg SSO cap, \$52.0M).

#### Scenario C: Creative Sandbox Mode (SANDBOX-01)
- **Direct Main Menu Entry:** Dedicated "CREATIVE SANDBOX" button on the title screen.
- **Unrestricted Parameters:** Unlimited budget (\$999.0M cap) and relaxed mass envelope (9999.0 kg).
- **Real-Time Telemetry:** Live gauges for Mass, Power Balance, Battery Eclipse DoD, and Propellant Budget.
- **Persistent Spacecraft Profiles:** In-workshop Save, Load, and Reset functionality persisting custom spacecraft configurations to `user://sandbox_spacecraft.json`.
- **Sandbox Watermark:** Active telemetry HUD watermark clearly indicating experimental sandbox mode.

---

### 2. Local Cooperative Team Mode (1–4 Players Pass-and-Play)

MARGIN includes a turn-based pass-and-play local cooperative mode designed for classrooms, engineering teams, and co-op gaming sessions (local pass-and-play only; not an online multiplayer service):
- **Configurable in Mission Briefing:** Toggle between Solo Flight and 1–4 Player Co-Op with custom officer names.
- **4 Distinct Specialist Roles:**
  1. **Mission Director (Player 1):** Strategic oversight, budget ceiling authorization, final launch go/no-go call, and inter-discipline tiebreaker.
  2. **Systems Engineer (Player 2):** Spacecraft bus architecture, power balance (solar margin & battery eclipse DoD), thermal control, structural mass margins, and subsystem reliability.
  3. **Science Lead (Player 3):** Payload selection, instrument calibration, observation targets, operational flight modes, and scientific throughput optimization.
  4. **Flight Dynamics & Comms Lead (Player 4):** Trajectory design (Direct vs. BLT), launch vehicle procurement, propellant Delta-V margin, and Deep Space Network downlink passes.
- **Role Attribution Banner:** Live top-of-screen role indicator throughout the Workshop, Launch Planning, and Mission Operations showing the active officer and their specific responsibilities.
- **Pre-Launch Flight Readiness Review (FRR):** Formal pre-flight voting gateway where all four officers review independent engineering criteria before launch commitment.
- **Team Coordination Debrief:** Dedicated debrief report tracking decision attribution, individual officer contributions, and collaboration efficiency without altering the underlying 8-pillar scoring math.

---

### 3. Interactive Mission Operations & Emergency Events

During the 12-month operational flight phase, missions encounter interactive emergency decision events that require immediate engineering trade-offs and produce persistent consequences:
- **Window 3 — Solar Proton Event (SPE) / Solar Particle Storm:**
  - *Option A: Full Safe Mode.* Suspend non-essential science instruments while maintaining essential power, thermal control, and communications. Protects sensitive avionics and optics from proton flux; reduces science output during the event.
  - *Option B: Partial Protection (Attitude Stance).* Perform an attitude-control maneuver to maintain sun/comm alignment while disabling vulnerable optical detectors. Secondary protected sensors stay active, preserving 75% science with minimal modeled degradation. (Described strictly as an attitude-control maneuver; orientation does not deflect solar protons).
  - *Option C: Continue Operations.* Maintain active observations. Preserves 100% science yield, but accepts increased modeled radiation-related equipment degradation (-7.5% equipment health) and persistent sensor SEU noise in future windows. (Radiation-risk calculations are educational simulation models).
- **Window 4 — Deep Space Network (DSN) Ground Station Outage:**
  - *Option A: Store Data in Solid-State Buffer.* Buffer science in solid-state recorder until ground station service resumes. Lowers risk of immediate data loss, but risks recorder buffer overflow if subsequent downlink capacity is exceeded.
  - *Option B: Use Backup Communication (Commercial S-Band Relay).* Divert downlink through commercial ground station networks at an educational operational cost of \$0.5M, successfully draining buffer.
- **Window 7 — Electrical Battery Emergency in Shadow:**
  - *Option A: Shed Non-Critical Load.* Temporarily disable non-essential instrument heaters and secondary sensors to lower eclipse power demand. Protects battery longevity (<42% DoD).
  - *Option B: Continue Full Operations.* Keep all payload sensors and heaters operating at full power throughout the eclipse shadow. Accepts deep discharge (>85% DoD) and accelerated modeled battery degradation (-5.0% battery SOH loss).
- **Audit Integration:** All player decisions, resource expenditures, and consequence logs are preserved and itemized in the Mission Debrief Engineering Decision Audit tab.

---

### 4. 3D Spacecraft Workshop
- **Subsystems (9 Categories, 30 Authentic Components):**
  - **Structure:** Modular Aluminum 6061 Monocoque, Carbon-Fiber Honeycomb Core, 3D-Printed Titanium Isogrid.
  - **Power:** Dual Deployable GaAs Triple-Junction Arrays, Body-Mounted Silicon Arrays, Ultra-Flex High-Efficiency Wings, Deployable Roll-Out Solar Array (ROSA).
  - **Energy Storage:** Commercial Li-ion Battery, Space-Grade LiFePO4 Pack, Solid-State High-Capacity Array.
  - **Thermal Control:** Passive MLI Blankets, Heat Pipes & Active Louvers, Redundant Heaters & RTD Loop.
  - **Propulsion:** Cold Gas RCS Thrusters, Hydrazine Monopropellant System, Dual-Mode Chemical Bipropellant System, 25 mN Hall-Effect Electric Propulsion.
  - **Attitude Determination & Control (ADCS):** Reaction Wheels & Star Trackers, Cold Gas Reaction Control, 3-Axis Magnetorquer & Sun Sensor Array.
  - **Communications:** Patch Antenna & S-Band Transponder, Medium-Gain Horn & X-Band Transponder, High-Gain Parabolic Reflector (Ka/X Band).
  - **Command & Data Handling (C&DH):** Radiation-Tolerant Rad750, Fault-Tolerant Dual-LEON3 Computer, High-Reliability Triple-Modular Core.
  - **Scientific Payloads:**
    - *Lunar Suite:* Helium-3 Proportional-Counter Neutron Spectrometer (LP-NS Heritage), Lunar Exploration Neutron Detector (LRO LEND Heritage), Mini-RF Synthetic Aperture Radar.
    - *Earth Climate Suite:* Multispectral Climate Radiometer (Sentinel-3 OLCI-inspired), GHG Imaging Spectrometer (OCO-2-inspired), Ku-band SAR Interferometric Cryosphere Altimeter (CryoSat-2 SIRAL-inspired).
- **Live 6-Resource Telemetry Gauges:** Launch Mass, Power Balance (sunlight surplus + battery eclipse DoD), Mission Budget, Data Storage Buffer, Comms Link Margin, and Orbit Lifetime.
- **Signature Feature — Trade-Off Echo:** Real-time engineering feedback explaining the aerospace ripple effect of every hardware decision.

---

### 5. Orbit & Launch Planning
- **Selectable Transfer Strategies:**
  - **Low-Energy Ballistic Transfer (WSB/BLT):** Fuel-efficient 83.7-day Weak Stability Boundary transit via Sun-Earth-Moon gravitational three-body interactions (citing 669.543 m/s Lunar Orbit Insertion retro-burn from JPL Monograph Series 12).
  - **Direct Conventional Transfer:** Fast 4.0-day translunar transit (citing 839.878 m/s impulsive LOI retro-burn from JPL Monograph Series 12).
  - **Direct SSO Insertion (ECS-01):** 705 km Sun-Synchronous polar launch with minimal circularization $\Delta V$ requirements.
- **Authoritative Educational Launch Vehicle Profiles:**
  - *Lunar Profiles:* Small Commercial Rideshare (\$14.0M, 260 kg TLI), Medium Commercial EELV-Class (\$32.0M, 450 kg TLI), Heavy Dedicated Booster (\$65.0M, 850 kg TLI).
  - *Polar SSO Profiles:* Polar Small Rideshare (\$12.0M, 380 kg SSO), Sun-Sync Medium Booster (\$26.0M, 720 kg SSO), Polar Heavy Dedicated (\$52.0M, 1400 kg SSO).
- **Automated Pre-Flight Gatekeeper:** Strictly validates launch vehicle payload capacity, fairing volume, fairing envelope dimensions, impulsive Delta-V requirements, and total mission budget.

---

### 6. Mission Debrief & 8-Pillar Evaluation
- **Comprehensive Scorecard (100% Deterministic, Weighted 0–100):**
  1. **Scientific Achievement (25%):** Target survey completeness, spatial resolution, and proxy verification.
  2. **Power & Eclipse Performance (15%):** Sunlight electrical surplus, peak battery DoD during orbital eclipses, and blackout prevention.
  3. **Budget Efficiency (10%):** Spacecraft development cost + launch vehicle procurement + 12-month flight operations expenditure vs. scenario cap.
  4. **Mass & Volume Efficiency (10%):** Structural mass margin and payload volume packing density.
  5. **Data Storage Management (10%):** Onboard recorder buffer utilization and zero overflow science loss.
  6. **Communications Throughput (10%):** Cumulative downlinked gigabits and RF link margin closure (+8.2 dB over ground stations).
  7. **Mission Lifetime & Schedule (10%):** Survival across 365 operational flight days.
  8. **System Reliability & Health (10%):** 50% pre-launch composite hardware reliability + 50% end-of-mission subsystem health.
- **Debrief Dossier Tabs:** Overview & Scorecard, Scientific Report & Targets, Engineering Decision Audit, 12-Month Interactive Timeline, Team Contributions, and Saved Designs Library.
- **Persistent Storage & Side-by-Side Comparison:** Save mission reports to browser local storage (IndexedDB `/userfs`), perform mathematical differential comparisons between designs, and delete obsolete runs.

---

### 7. Lunar Frontier — 3D Surface Exploration Mode
- **Playable 3D Surface Experience:** Transition from orbital planning to direct 3D lunar surface operations.
- **Piloted Rover/Lander Mechanics:** Real-time physics navigation across rugged Shackleton Crater terrain.
- **Surface Science Tasks:** Deploy surface probes, analyze volatile regolith samples, manage surface battery/solar power in extreme shadowing, and establish local beacons.

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

## ⚠️ Educational Simulation Disclaimers & Assumptions

*MARGIN is an independent educational aerospace simulation created for academic, design, and simulation demonstration purposes. It is not affiliated with, endorsed by, or sponsored by NASA, the Jet Propulsion Laboratory (JPL), the European Space Agency (ESA), or any commercial aerospace launch provider.*

To maintain clear separation between published literature and simulation mechanics:

1. **Scientific Literature Grounding:**
   - Planetary epithermal neutron moderation physics (LP-NS Feldman et al., LRO LEND Mitrofanov et al.).
   - Ballistic Weak Stability Boundary transfer trajectories (NASA/JPL Monograph 12 Parker & Anderson).
   - Radar altimetry, interferometry, and thermal infrared surface observation principles (Mini-RF Raney et al., CryoSat-2 SIRAL Wingham et al., Sentinel-3 OLCI/SLSTR, OCO-2).

2. **In-Game Educational Estimates & Simplifications:**
   - **Instrument Parameters:** Instrument mass (e.g. 58 kg for the CryoSat-2 SIRAL-inspired altimeter), power consumption (-135W), data rates, and procurement costs (\$42.0M) are in-game educational models calibrated for gameplay trade-off tension rather than certified flight specifications of the heritage spacecraft.
   - **Launch Vehicle Family:** Launch vehicle pricing (\$12.0M to \$65.0M) and payload capacities (TLI/SSO/LEO) are educational approximations representing distinct commercial launch classes.
   - **Operational Costs & Emergency Events:** Emergency event cost penalties (e.g. \$0.5M commercial antenna pass fees), radiation degradation percentages (-7.5% SOH), and battery thermal penalties are stylized educational gameplay mechanics.
   - **Reference Orbit Selection:** The 705 km altitude / 98.2° inclination Sun-Synchronous Orbit (SSO) is a selected educational reference orbit modeled on the Landsat/Earth Observing System morning constellation architecture; it is not a universal requirement for all Earth observation missions.
   - **AMOC Observational Scope & Ocean Altimetry:** Satellite surface skin temperature and SAR ocean roughness observations provide valuable indirect surface indicators for subpolar gyre dynamics, but do not directly measure steric dynamic height (the mission does not model a dedicated microwave ocean radar altimeter) or full-depth Atlantic Meridional Overturning Circulation (AMOC) volume transport; sustained AMOC monitoring fundamentally requires deep-water in-situ mooring networks (e.g. RAPID/OSNAP) and ocean circulation modeling.
   - **Volatile Proxies:** Regolith hydrogen enhancement detected via neutron flux moderation is modeled strictly as a scientific proxy for volatile concentration and does not constitute definitive proof of surface water ice at every surveyed crater.

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

Run each automated test suite headless via Godot Engine (228 tests across 9 comprehensive suites, 100% passing):
```bash
# 1. Maneuver & Transfer Strategy Audit (15 tests)
Godot --headless --path . -s res://margin/tests/test_maneuver_audit.gd

# 2. Mission Operations Simulation Suite (13 tests)
Godot --headless --path . -s res://margin/tests/test_mission_operations.gd

# 3. Mission Debrief & 8-Pillar Scoring Suite (21 tests)
Godot --headless --path . -s res://margin/tests/test_mission_debrief.gd

# 4. Full End-to-End Gameplay Integration Suite (15 tests)
Godot --headless --path . -s res://margin/tests/test_end_to_end.gd

# 5. Lunar Frontier 3D Surface Exploration Suite (19 tests)
Godot --headless --path . -s res://margin/tests/test_lunar_frontier.gd

# 6. Interactive Mission Operations & Emergency Events (22 tests)
Godot --headless --path . -s res://margin/tests/test_interactive_operations.gd

# 7. Earth Climate Sentinel (ECS-01) LEO SSO Scenario (51 tests)
Godot --headless --path . -s res://margin/tests/test_earth_climate_sentinel.gd

# 8. Local Cooperative Team Mode & FRR Voting (44 tests)
Godot --headless --path . -s res://margin/tests/test_team_coop.gd

# 9. Creative Sandbox Mode & Spacecraft Persistence (28 tests)
Godot --headless --path . -s res://margin/tests/test_sandbox_mode.gd

# Optional: Full Browser Headless Chrome QA (Interactive Canvas, IndexedDB Persistence, WebGL)
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
│   │   ├── component_data.gd        # 30 Components across 9 Subsystems
│   │   ├── launch_vehicle_data.gd   # Authoritative Lunar & Polar SSO Launch Vehicles
│   │   ├── mission_data.gd          # Mission LSP-01 Constants & Constraints
│   │   ├── mission_evaluation_data.gd # Evaluation Storage & Local Comparison
│   │   ├── mission_operations_data.gd # 12 Monthly Windows, Events, Craters & Sentinels
│   │   ├── mission_scenario.gd      # LSP-01, ECS-01, and SANDBOX-01 Scenario Model
│   │   ├── orbit_data.gd            # Orbit Profiles & Stationkeeping
│   │   ├── team_data.gd             # 4 Co-Op Roles, FRR Voting & Attribution
│   │   └── transfer_data.gd         # Direct, Low-Energy BLT & SSO Transfers
│   ├── scenes/                      # 3D Scenes & User Interfaces
│   │   ├── main_menu.tscn           # Title Screen, Scenario Select & Sandbox Entry
│   │   ├── mission_briefing.tscn    # Flight Readiness Dossier & Co-Op Setup
│   │   ├── workshop.tscn            # 3D Craft Workshop, Live Margins & Sandbox Save/Load
│   │   ├── launch_planning.tscn     # Trajectory Planning & Pre-Flight FRR Gatekeeper
│   │   ├── mission_operations.tscn  # 12-Month Flight Command Center & Event Modals
│   │   └── mission_debrief.tscn     # 8-Pillar Scorecard, Team Audit & Saved Comparisons
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
│   ├── tests/                       # Automated Verification Suites (228 Tests)
│   │   ├── test_maneuver_audit.gd   # Maneuvers & Propulsion Limits (15/15 PASS)
│   │   ├── test_mission_operations.gd # Operations Flight Dynamics (13/13 PASS)
│   │   ├── test_mission_debrief.gd  # 8 Pillars & Scorecard Math (21/21 PASS)
│   │   ├── test_end_to_end.gd       # Complete Gameplay Integration (15/15 PASS)
│   │   ├── test_lunar_frontier.gd   # 3D Surface Exploration & Physics (19/19 PASS)
│   │   ├── test_interactive_operations.gd # Emergency Decisions & Consequence Audit (22/22 PASS)
│   │   ├── test_earth_climate_sentinel.gd # ECS-01 Earth Observation & SSO (51/51 PASS)
│   │   ├── test_team_coop.gd        # 1-4 Player Co-Op & FRR Voting (44/44 PASS)
│   │   ├── test_sandbox_mode.gd     # Unrestricted Sandbox & Persistence (28/28 PASS)
│   │   └── run_full_browser_qa.js   # Full Browser UI & IndexedDB CDP Test
│   ├── ui/                          # Aerospace Dark Theme & Styling
│   └── web/                         # Branded HTML Shell with Progress Bar
├── build/
│   └── web/                         # Static Production Web Export
│       ├── index.html               # Custom Branded Shell with Real-Time Progress
│       ├── index.js                 # Godot Engine JavaScript Bridge
│       ├── index.wasm               # Optimized 28.0 MB WASM Binary
│       └── index.pck                # Virtual Flight Package
├── crystal_dash/                    # Original Practice Game (Preserved Intact)
├── vercel.json                      # Vercel Deployment Configuration
├── project.godot                    # Godot Engine Project Definition
└── README.md                        # Production Documentation
```
├── crystal_dash/                    # Original Practice Game (Preserved Intact)
├── vercel.json                      # Vercel Deployment Configuration
├── project.godot                    # Godot Engine Project Definition
└── README.md                        # Production Documentation
```

---
*Developed with Godot Engine 4.7 for the Space Mission Design Game challenge.*
