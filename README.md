# MARGIN — THE SPACE MISSION DESIGN GAME
### *HELIOS-4: The Last Line of Defense*

🎮 **Live Production Deployment:** [https://margin-space-mission-game.vercel.app/](https://margin-space-mission-game.vercel.app/)

**MARGIN** is an authentic 3D aerospace engineering and spaceflight operations simulation built with Godot Engine 4.7. Designed in the spirit of the NASA Space Mission Design challenge, MARGIN puts players in command of designing, launching, navigating, and commissioning an emergency solar-weather sentinel spacecraft: **HELIOS-4**.

Unlike generic arcade flight games or static dashboards, MARGIN combines rigorous mathematical flight physics, multi-stage Tsiolkovsky rocket equations, Max-Q dynamic pressure aerodynamics, deep-space astrodynamics, and NASA DONKI space-weather data into a unified, playable campaign.

---

## 🛰️ The HELIOS-4 Campaign

### Background & Mission Context (Story Year: 2038)
During an elevated solar-activity peak in 2038, existing space-weather sentinels at Sun-Earth Lagrange Point 1 (L1) have degraded. Active Region AR-4890 threatens an extreme Coronal Mass Ejection (CME) superstorm. An emergency mission — **HELIOS-4** — is authorized to deploy a replacement sentinel into a periodic 3D halo orbit at Sun-Earth L1 (~1.5 million km sunward from Earth) to provide 15 to 60 minutes of critical early warning for Earth's power grids and orbital infrastructure.

### Four Cooperative Pass-and-Play Roles
Designed for individual play or local team collaboration (pass-and-play):
1. **Propulsion Engineer (PROPULSION):** Engine selection, thrust ratings, propellant loading, specific impulse ($I_{sp}$), and multi-stage $\Delta V$. Manages ignition sequencing and throttle profiles.
2. **Structural Architect (STRUCTURES):** Structural framework, fairing envelope, center-of-mass (CoM) vs. center-of-pressure (CoP), aerodynamic static margins, and dynamic pressure ($q$) corridors during ascent.
3. **Astrogator (TRAJECTORY):** Launch azimuth, gravity turn pitch profiles, Earth-to-L1 transfer trajectories (Direct vs. Weak Stability Boundary), and L1 halo-orbit insertion burns.
4. **Systems Officer (SYSTEMS):** Power budget, solar array sizing, battery capacity, rad-hardened avionics, plasma analyzer health, and early-warning telemetry link margins.

---

## 🚀 Campaign Structure (Four Interactive Flight Phases)

### Phase 1: Briefing, Engineering Hangar & Flight Readiness Review
- **Interactive 3D Assembly Hangar:** 360° orbit camera around the central launch vehicle. Configure Stage 1 booster engines, fuel tanks, grid fins, interstage adapters, Stage 2 vacuum propulsion, and the scientific probe bus.
- **Live Engineering Telemetry:** Dynamic calculations of Total Wet Mass, Liftoff TWR (safe pad clearance 1.20–1.85), Aerodynamic Static Margin (>1.2 calibers for passive aerodynamic stability), Multi-Stage $\Delta V$ ($\ge 9,100\text{ m/s}$ for Trans-L1 injection), Power Balance, and Mission Budget ceiling (\$185.0M).
- **Formal Flight Readiness Review (FRR):** Multi-specialist Go / No-Go review gatekeeper requiring all engineering thresholds to be verified before launch authorization.

### Phase 2: Earth Launch & Max-Q Ascent
- **Playable 3D Flight Control:** Real-time throttle and pitch gimbal control through the dense lower atmosphere.
- **Dynamic Pressure ($q = \frac{1}{2}\rho v^2$) Corridor:** Throttle back through the structural Max-Q zone (~30–38 kPa at 10–14 km altitude) to prevent structural breakup.
- **Staging & Orbital Insertion:** Jettison Stage 1 booster, ignite Stage 2 vacuum engine, separate payload fairings in the upper atmosphere, and execute horizontal circularization into a 165 km Earth parking orbit.

### Phase 3: Deep Space Transfer & Solar Storm Crisis
- **Trans-L1 Hyperbolic Injection:** Execute the primary injection burn departing Earth parking orbit on a sunward hyperbolic escape trajectory.
- **Relativistic Spaceflight Immersion:** 64-bit coordinate space with frozen Sun-Earth aligned reference frame, realistic Earth and Moon recession, and velocity-scaled space dust streaks.
- **Interactive Crisis Events:** Navigate solar particle events (SPE), micro-meteoroid valve anomalies, and navigation drift using real engineering trade-offs (Safe Mode, instrument isolation, or continued observation).

### Phase 4: Sun-Earth L1 Halo-Orbit Insertion & Commissioning
- **Halo-Orbit Insertion Burn:** Execute the retro-capture maneuver into a periodic 3D halo orbit around Sun-Earth L1 ($L_1 \approx 1.5\times 10^6\text{ km}$ sunward).
- **Instrument Commissioning:** Deploy the magnetometer boom and open the Faraday Cup aperture cover to detect live solar wind plasma parameters ($B_z$, proton density, and velocity).
- **Earth DSN Lock & Telemetry Transmission:** Slew the high-gain parabolic antenna to lock onto Earth's Deep Space Network (8.4 GHz X-band carrier) and transmit real-time CME early-warning data packets.
- **Mission Debrief:** Comprehensive evaluation across Mission Trajectory, Spacecraft Health, Telemetry Reliability, and Early-Warning Margin.

---

## 🛠️ Technology Stack

- **Game Engine:** [Godot Engine 4.7.2 (Stable Official)](https://godotengine.org)
- **Renderer:** GL Compatibility (WebGL 2.0 / OpenGL ES 3.0) for universal desktop and mobile browser compatibility.
- **Physics Engine:** Jolt Physics 3D.
- **Coordinate System:** 64-bit floating-point astronomical reference frame with Sun-Earth aligned coordinates.
- **UI System:** Custom high-DPI procedural aerospace HUD widgets (gauges, radar scopes, sparklines, readiness bars).
- **Web Export:** Single-threaded WebAssembly (WASM) with Emscripten IDBFS persistence.
- **Hosting / Cloud Deployment:** Vercel Static Hosting (`build/helios4_test`) with custom HTTP headers for WebAssembly MIME types (`application/wasm`) and instant revalidation.

---

## 📚 Scientific References & Astrodynamics

MARGIN is built upon real-world astrodynamics and space-weather physics:

1. **Sun-Earth L1 Lagrange Point Astrodynamics:**
   - Sun-Earth L1 is located approximately $1.5\times 10^6\text{ km}$ from Earth along the Sun-Earth axis (~1% of an Astronomical Unit; *not* the midpoint).
   - Collinear Lagrange points are dynamically unstable saddle equilibria. Periodic 3D halo orbits require periodic stationkeeping burns (~15–30 m/s/year; modeled as educational game thresholds).
2. **NASA DSCOVR, SOHO & ACE Heritage:**
   - Inspired by the NASA Deep Space Climate Observatory (DSCOVR) PlasMag payload, SOHO, and ACE.
   - Measures solar wind velocity ($v_{sw}$), proton density ($N_p$), and interplanetary magnetic field orientation ($B_z$) to detect Earth-directed coronal mass ejections.
3. **NASA DONKI / CCMC Space Weather Service:**
   - Real-world space weather event benchmarks modeled from the NASA Space Weather Database of Notifications, Knowledge, Information (DONKI) hosted by CCMC.

---

## 🧪 Automated Test Verification

The project includes automated headless test suites validating all physics equations, mission logic, and campaign continuity:

```bash
# 1. Flagship HELIOS-4 Full Campaign Integration Suite (96 tests)
/Users/omar/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . -s margin/tests/test_helios4_campaign.gd

# 2. Part 3 Deep Space Transfer & Crisis Suite (47 tests)
/Users/omar/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . -s margin/tests/test_helios4_deep_space.gd

# 3. Part 4 L1 Arrival, Halo Orbit & Telemetry Commissioning Suite (43 tests)
/Users/omar/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . -s margin/tests/test_helios4_l1_commissioning.gd

# 4. Part 2 Launch Pad, Max-Q & Ascent Usability Suite (41 tests)
/Users/omar/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . -s margin/tests/test_helios4_launch_usability.gd

# 5. Spaceflight Immersion, Coordinate Frame & 64-bit Astrodynamics Suite (1,062 tests)
/Users/omar/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . -s margin/tests/test_helios4_spaceflight_immersion.gd
```

---

## 📂 Project Directory Structure

```
godot-practice/
├── margin/                          # MARGIN Authoritative Game Module
│   ├── data/                        # Flight Databases & Campaign State
│   │   ├── component_data.gd        # 30 Authenticated Components across 9 Subsystems
│   │   ├── donki_service.gd         # NASA DONKI CCMC Space Weather Event Integration
│   │   ├── helios4_campaign_data.gd # Authoritative HELIOS-4 Flagship Campaign Architecture
│   │   ├── launch_vehicle_data.gd   # Launch Vehicle Performance Database
│   │   ├── mission_data.gd          # NASA Constants & Constraints
│   │   ├── mission_evaluation_data.gd # Debrief & Evaluation Metrics
│   │   ├── mission_scenario.gd      # Scenario Registry
│   │   ├── orbit_data.gd            # Astrodynamics & Orbit Models
│   │   ├── team_data.gd             # 4-Specialist Team Allocation Models
│   │   └── transfer_data.gd         # Direct & Weak Stability Boundary Transfer Trajectories
│   ├── materials/                   # PBR Aerospace Shaders & Materials
│   │   └── spacecraft_materials.gd  # Multi-Layer Insulation, Solar Panels & Metal Alloys
│   ├── scenes/                      # 3D Flight & Campaign Scenes
│   │   ├── main_menu.tscn           # Mission Command Center Title Screen
│   │   ├── helios4_prologue.tscn    # Part 1: 2038 Crisis Briefing & Authorization
│   │   ├── helios4_team_assignment.tscn # Part 1: Specialist Allocation
│   │   ├── helios4_hangar.tscn      # Part 1: 3D Multi-Stage Rocket & Probe Assembly
│   │   ├── helios4_engineering_review.tscn # Part 1: Flight Readiness Review (FRR)
│   │   ├── helios4_launch.tscn      # Part 2: Earth Launch & Max-Q Dynamic Pressure
│   │   ├── helios4_deep_space.tscn  # Part 3: Deep Space Trajectory & Solar Storm
│   │   ├── helios4_crisis.tscn      # Part 3: Spacecraft Storm Survival & Safe Mode
│   │   ├── helios4_l1_arrival.tscn  # Part 4: Sun-Earth L1 Halo Orbit & Commissioning
│   │   └── helios4_debrief.tscn     # Part 4: Final Mission Evaluation & Telemetry
│   ├── scripts/                     # Flight Mechanics & Physics Controllers
│   │   ├── helios4_hangar_controller.gd
│   │   ├── helios4_engineering_review_controller.gd
│   │   ├── helios4_launch_controller.gd
│   │   ├── helios4_deep_space_controller.gd
│   │   ├── helios4_crisis_controller.gd
│   │   ├── helios4_l1_arrival_controller.gd
│   │   ├── helios4_debrief_controller.gd
│   │   ├── helios4_prologue_controller.gd
│   │   ├── helios4_team_assignment_controller.gd
│   │   ├── helios4_rocket_3d.gd     # Procedural Multi-Stage 3D Rocket & Probe Mesh
│   │   ├── helios4_hud_widgets.gd   # Procedural High-DPI Aerospace Gauges & Radar
│   │   ├── main_menu_controller.gd  # Title Screen & 3D Background Controller
│   │   ├── orbit_camera.gd          # 3D Orbit Camera Controller
│   │   ├── spacecraft_3d.gd         # Modular 3D Spacecraft Mesh Generator
│   │   ├── spacecraft_state.gd      # Spacecraft Systems & Power Telemetry
│   │   ├── scoring_engine.gd        # Evaluation Math & Scorecard Engine
│   │   └── trade_off_echo.gd        # NASA Trade-Off Real-Time Feedback
│   ├── tests/                       # Automated Test Suites (1,289 Tests)
│   │   ├── test_helios4_campaign.gd
│   │   ├── test_helios4_deep_space.gd
│   │   ├── test_helios4_l1_commissioning.gd
│   │   ├── test_helios4_launch_usability.gd
│   │   └── test_helios4_spaceflight_immersion.gd
│   ├── ui/                          # Aerospace Dark Theme & Design Tokens
│   └── web/                         # Custom Web Shell & Progress Streamer
├── build/
│   └── helios4_test/                # Static Web Export Assets
├── export_presets.cfg               # Godot Engine Web Export Configuration
├── icon.svg                         # Application Icon
├── project.godot                    # Authoritative Godot 4.7.2 Project Definition
├── vercel.json                      # Vercel Deployment Configuration
└── README.md                        # Documentation
```

---
*Developed with Godot Engine 4.7 for the Space Mission Design Game challenge.*
