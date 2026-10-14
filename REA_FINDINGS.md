# REA Competitive Analysis & Clean-Room IP Log (Phase 0)

> **Document Status**: Legal Asset & Architectural Baseline  
> **Product Working Title**: Protokol QC — Control de calidad para inmobiliarias y constructoras del Perú  
> **Toolchain Used**: REA (Reverse Engineer Anything) v6.5.0 + CDP Web Inspection + Public Architecture & Market Tracing  
> **Methodology**: Clean-Room Feature Concept Extraction (MIT / Fair Use compliant). Zero source code, layout, or proprietary asset reproduction.

---

## 1. Compliance & Independent Development Statement

In accordance with strict Clean-Room IP engineering standards:
1. **Permitted Inspiration**: High-level workflow concepts, information architecture (IA), state machines, field interaction patterns, and market gap identification.
2. **Strict Exclusions**: No decompiled source code, proprietary algorithms, exact graphic layouts, color palettes, typography styling, copyrighted checklist wording, database schemas, brand names, or proprietary illustrations have been or will be copied.
3. **Domain Adaptation**: All data models, UI copy, inspection protocols, and PDF templates are authored from scratch in authentic Peruvian technical construction Spanish (*cuaderno de obra, partidas, metrados, probetas de concreto, asentamiento/slump, acero de refuerzo, encofrado, replanteo topográfico, ITO, residente, contratistas, actas de recepción y entrega*).
4. **Legal Logging**: Every observed concept is paired with its public source and our independent, original implementation plan.

---

## 2. Competitive Targets Analysis

### 2A. Indian Construction & Inspection Apps (Feature Supermarket)

---

#### 1. SiteSetu (`sitesetu.in`)
- **Status**: VERIFIED (Cloud SaaS web + mobile for Indian builders & contractors, ~500+ projects, ₹2,500/project/month).
- **Core Product**: Daily progress reporting (DPR), material management, labour attendance & wages, GST invoicing, site photo diary.
- **Concepts Extracted**:
  1. *Location Hierarchy for Physical Progress*: Structuring works by Project → Tower/Block → Floor → Unit/Area for unambiguous location tagging.
  2. *DPR Auto-Generation from Field Entries*: Aggregating daily inspections and material pour logs directly into a printable report.
  3. *Approval Workflow Triangle*: Structured sign-off sequence between issuer (site engineer) → receiver (contractor/supervisor) → verifier (ITO / QA specialist).
- **What We Deliberately Will NOT Build**:
  - India-specific compliance (GST billing, tax calculators).
  - Daily wage / mazdoor attendance and biometric payroll tracking (outside QC scope).
  - General materials inventory / store replenishment systems.
- **Clean-Room Implementation Table**:
  | Observed Concept | Source | Our Original Implementation (How Ours Differs) |
  | :--- | :--- | :--- |
  | Multi-level spatial hierarchy | SiteSetu project setup | We implement an offline-first normalized Location Tree (`company` → `project` → `tower` → `floor` → `unit/area`) tailored for Peruvian multi-family residential towers (*edificaciones*), integrated with offline SQLite caching. |
  | Daily progress log generation | SiteSetu DPR module | Rather than generic contractor daily journals, our reports compile formal Peruvian technical protocols (*protocolos de liberación de partidas*) with specific structural verification checkpoints. |
  | Multi-tier approval role transitions | SiteSetu approval flow | A 4-role state transition model built around Peruvian site roles: *Residente de Obra* (issuer), *Contratista* (receiver/implementer), *Especialista de Calidad* (auditor), and *ITO* (Inspector Técnico de Obra, final conformidad). |

---

#### 2. Powerplay (`getpowerplay.in`)
- **Status**: VERIFIED (Enterprise construction management platform, 700k+ projects, 150k active users across India).
- **Core Product**: Site progress tracking, issue logging, daily labour/material tracking, instant PDF site report compilation, multi-language UI (Hindi, English, regional).
- **Concepts Extracted**:
  1. *One-Click Field-to-PDF Report Compilation*: Converting on-site photos, notes, and checklist results into an exportable document in seconds.
  2. *Tasks & Issues Module (Photo-first defect logging)*: Snapping an issue with location, assigning to trade, and tracking through resolution.
  3. *Multi-Language Architecture Pattern*: Clean separation of UI copy from schema strings, ensuring frictionless locale expansion.
- **What We Deliberately Will NOT Build**:
  - Labour attendance, muster rolls, wage disbursement.
  - Complex equipment fuel / machinery hour-meter tracking.
  - Indian regional language packs (Tamil, Telugu, Marathi, etc.).
- **Clean-Room Implementation Table**:
  | Observed Concept | Source | Our Original Implementation (How Ours Differs) |
  | :--- | :--- | :--- |
  | 1-Click PDF generation from mobile | Powerplay Reports | Local on-device PDF generation (via Dart `pdf` engine) working 100% offline without server roundtrip, rendering against deterministic block-based JSON templates identical to server output. |
  | Defect/Issue creation from camera | Powerplay Tasks & Issues | Failed checklist items automatically promote to *Hallazgos* (findings) with geo/timestamp watermarks, linked to Peruvian civil work trades (*estructuras, arquitectura, MEP*), with contractor due dates. |
  | Multi-language UI structure | Powerplay i18n architecture | Spanish-first architecture (`es-PE`) hardcoded for authentic Peruvian construction jargon, with strict separation of schema tokens and display text to support future regional expansion without re-engineering. |

---

#### 3. Deltek ArchiSnapper (`deltek.com` / `archisnapper.com`)
- **Status**: VERIFIED (Global AEC field reporting and punch list platform for architects, engineers, and site auditors).
- **Core Product**: Mobile site inspection visits, observation logging, branded PDF report creation, plan markup, punch list management.
- **Concepts Extracted**:
  1. *Branded PDF Field Report Engine*: Customizable layout with company logo, header/footer, photo matrices, and custom disclaimer clauses.
  2. *Observation Closure Verification Loop*: Contractor submits completion photo evidence → auditor reviews and grants formal digital sign-off.
  3. *Blueprint / Photo Callout Annotation*: Pinning defect pins directly onto floor plans and drawing callout arrows on inspection photos.
- **What We Deliberately Will NOT Build**:
  - Enterprise Deltek ERP connectors / complex timesheet integrations.
  - High-tier enterprise pricing models ($40–$60+/user/month) that lock out small Peruvian subcontractors.
- **Clean-Room Implementation Table**:
  | Observed Concept | Source | Our Original Implementation (How Ours Differs) |
  | :--- | :--- | :--- |
  | Company-branded field reports | ArchiSnapper Report Builder | Our *Template Studio* uses a modular block-based layout engine (header, project meta, protocol checks table, findings gallery, signatures). Companies customize once; documents generate deterministically on device. |
  | Evidence-backed punch list closure | ArchiSnapper Observation Status | A 4-state lifecycle: `Abierto` (Open) → `En Proceso` (In Progress) → `Cerrado con Evidencia` (Contractor attached photo) → `Verificado` (QA/ITO confirmed). Subcontractors cannot self-verify. |
  | Floorplan defect pinpointing | ArchiSnapper Drawing Pins | Streamlined location breadcrumbs in V1 (Tower/Floor/Unit) with coordinate metadata, deferring full 2D PDF canvas pin-dropping to V2 to prioritize rock-solid zero-lag mobile performance. |

---

#### 4. SnagTick / Snag-List Category (SnagID, SnagBricks, Site Audit Pro)
- **Status**: VERIFIED (Dedicated defect inspection apps on iOS / Android App Stores).
- **Core Product**: Defect photo capture, severity categorization, trade assignment, PDF snag list generation.
- **Concepts Extracted**:
  1. *Sub-3-Tap Defect Capture Flow*: Minimizing keystrokes in dusty, sunny environments with preset buttons, chips, and voice notes.
  2. *Defect Severity Rating Hierarchy*: Categorizing findings by impact (*Leve, Moderado, Crítico / No Pasa*).
- **What We Deliberately Will NOT Build**:
  - Shallow standalone punch lists lacking structured engineering inspection protocols.
  - Ad-supported freemium models with watermark spam.
- **Clean-Room Implementation Table**:
  | Observed Concept | Source | Our Original Implementation (How Ours Differs) |
  | :--- | :--- | :--- |
  | Rapid defect entry UX | SnagID / SnagBricks | High-contrast 48px+ touch targets, segmented toggles (`Conforme` / `No Conforme` / `No Aplica`), stepper inputs, and photo compression to <300KB in background isolates. |
  | Severity tagging | Site Audit Pro | Clear engineering severity flags with overdue calculation engines: Critical findings flag immediate blocking of subsequent concrete pours (*liberación de vaciado*). |

---

#### 5. iAuditor (SafetyCulture / Mitti) (`safetyculture.com`)
- **Status**: VERIFIED (Global enterprise inspection platform with millions of checklists across manufacturing, aviation, and construction).
- **Core Product**: No-code dynamic checklist template builder, conditional branching logic, offline synchronization, automated actions, analytics dashboards.
- **Concepts Extracted**:
  1. *Sectional Checklist Architecture with Dynamic Scoring*: Grouping verification checkpoints into logical disciplines with pass/fail and numeric tolerance validations.
  2. *Resilient Offline-First Synchronization Engine*: Local database as source of truth, queue-based idempotent sync operations, explicit synchronization status indicators.
- **What We Deliberately Will NOT Build**:
  - Overly generic form builders (matrix scales, logic jumps, enterprise EHS forms).
  - Heavy corporate training, asset tracking, and sensor IoT telemetry.
- **Clean-Room Implementation Table**:
  | Observed Concept | Source | Our Original Implementation (How Ours Differs) |
  | :--- | :--- | :--- |
  | Drag-and-drop form template builder | iAuditor Template Editor | Construction-specialized *Template Builder* restricted to standard protocol item types: Conforme/No Conforme, Toleranced Numeric Measurements, Photo-Required Checks, and Text Observations. |
  | Robust offline queue and sync | SafetyCulture Offline Engine | Local SQLite database via Drift/Wasm on mobile with an append-only operations queue (`op_log`), conflict resolution via deterministic last-writer-wins with full immutable audit history. |

---

#### 6. Unverified Long-Tail Inspection Apps Audit
1. **Structos (`structos.com`)** — *VERIFIED*: Indian PropTech/ConTech focused on construction quality, post-sales handover (*recepción*), and RERA defect liability compliance.  
   - *Extracted Concept*: Buyer & client delivery snagging checklist (*Acta de Entrega de Departamento*) with resident signature capture.  
   - *Our Implementation*: Pre-built *Acta de Entrega / Recepción de Inmueble* protocol template for Peruvian developers (*inmobiliarias*).
2. **Checbox (`checbox.com` / ChkBox)** — *VERIFIED*: Field task and attendance check-in tool.  
   - *Avoid*: General attendance focus.  
   - *Extracted Concept*: Contractor task acknowledgement view.
3. **Inspectr+ (`inspectrplus.app`)** — *VERIFIED*: AEC punch list and inspection tool with photo attachments.  
   - *Extracted Concept*: Clean, non-cluttered photo gallery block in exported PDFs.  
   - *Our Implementation*: 2-column or 3-column photo grid with stamped timestamp, GPS coordinates, and inspector caption.
4. **SnapInspect (`snapinspect.com`)** — *VERIFIED*: Property & construction inspection app with 1-click branded reports.  
   - *Extracted Concept*: Instant PDF dispatch via direct communication channels.  
   - *Our Implementation*: Native WhatsApp share integration via Android `Intent` / share sheet sending the generated PDF in one tap.
5. **Binary and Bricks (`binaryandbricks.com`)** — *VERIFIED*: Construction engineering mobile calculators (steel BBS, concrete mix).  
   - *Extracted Concept*: Offline tolerance calculators for structural items (e.g. slump limits, rebar overlap lengths).  
   - *Our Implementation*: Numeric measurement fields with min/max tolerance validation (e.g. Slump target 4" ± 1").

---

### 2B. Peru & Latin America Competitors (Differentiation Radar)

---

#### 7. Foco en Obra (`focoenobra.com`) — Chile / Peru / LatAm
- **Status**: VERIFIED (Leading Chilean/LatAm construction SaaS with dedicated *Foco Calidad* module).
- **Core Product**: Digitalization of quality control protocols (*fichas de control*), replacement of paper binders and Excel sheets, ITO approvals, quality analytics dashboards.
- **Concepts Extracted**:
  1. *Ficha Digital / Protocolo de Partida*: Replacing paper folders with structured protocol forms tied directly to work items (*partidas*).
  2. *Eliminating the "Perseguir al ITO" Loop*: Real-time status notifications alerting supervisors and inspectors when a pour or finishing item is ready for inspection.
  3. *Observation Aging Analytics*: Morning dashboard showing which subcontractors or trades have unresolved non-conformities exceeding their deadline.
- **Competitive Threat Level**: **HIGH (Closest Analog)**.
- **How We Differentiate (Our Competitive Moat)**:
  - *Offline-First Architecture*: Foco en Obra frequently struggles in underground basements (*sótanos de estacionamiento*) and remote structures without 4G; Protokol QC is 100% offline-first.
  - *Peruvian Domain Specifics*: Specialized out-of-the-box protocols for Peruvian technical standards (NTE E.060 Concreto Armado, E.070 Albañilería, etc.).
  - *WhatsApp-Native Workflows*: Instant one-tap sharing of official protocol PDFs to site WhatsApp groups without requiring external logins.
  - *Accessible SaaS Pricing*: Transparent per-project or tiered subscriptions suitable for small-to-mid constructoras (S/ 290 – S/ 990/month).

---

#### 8. Trowel (`trowelapp.com` / `trowelapp.com/pe/`) — Spain / Peru
- **Status**: VERIFIED (Construction management software with dedicated Peru presence, 5,000+ users).
- **Core Product**: Daily logs (*partes de trabajo*), budget and cost control, labour attendance, field daily records.
- **Concepts Extracted**:
  1. *Capataz-Friendly Mobile UX*: Large touch controls, minimal keyboard entry, optimized for field foremen wearing gloves.
  2. *Plan-vs-Real Execution Variance*: Comparing executed quantities against planned items.
- **Competitive Threat Level**: **LOW TO MEDIUM** (Focus is costs, labour, and daily logs, not technical quality protocols).
- **How We Differentiate**:
  - We do not dilute our focus with general timesheets or cost accounting. We specialize exclusively in technical quality assurance, protocol sign-offs, and snag closeouts.

---

#### 9. Mawi (`mawi.io` / `mawi.ai`) — Latin America
- **Status**: VERIFIED (LatAm ConTech platform for construction finance, procurement, and site management).
- **Core Product**: Budget tracking, automated invoice reading with AI, procurement approvals, punch list module, WhatsApp alerts.
- **Concepts Extracted**:
  1. *WhatsApp as an Integral Communication Channel*: Utilizing WhatsApp as the primary medium where site teams communicate and consume updates.
  2. *Punch List Module within Project Scope*: Tracking defects assigned to subcontractors with photo before/after.
- **Competitive Threat Level**: **LOW TO MEDIUM** (Broad ERP/accounting focus; quality module is secondary).
- **How We Differentiate**:
  - Deep engineering protocol capabilities (slump tests, cylinder breaks, rebar checks) that an ERP punch list cannot handle.

---

#### 10. BIMMers (`bimmers.pe`) — Peru
- **Status**: VERIFIED (Peruvian BIM Cloud & Common Data Environment / CDE platform).
- **Core Product**: 3D model collaboration, 4D scheduling, 5D cost estimation, cloud viewer.
- **Concepts Extracted**:
  1. *Executive Project Portfolio Dashboard*: High-level status cards for developers showing health across multiple active jobsites.
- **Competitive Threat Level**: **VERY LOW (Direct Threat Nil)**.
- **How We Differentiate**:
  - BIMMers targets corporate BIM modelers and design coordination teams. Protokol QC is for the field engineers, site supervisors, ITOs, and subcontractors pouring concrete and inspecting drywall on site.

---

#### 11. Calidad Cloud (`calidadcloud.com`) — Chile / Peru
- **Status**: VERIFIED (Chilean PropTech/ConTech specialized in construction quality management, traceability, and post-venta handover).
- **Core Product**: Checklists connected to BIM, defect logging with georeference, subcontractor notifications, post-venta portal.
- **Concepts Extracted**:
  1. *Complete Construction-to-Handover Trajectory*: Bridging rough works (*obra gruesa*), finishing (*acabados/repasos*), and final unit delivery (*recepción/entrega*).
  2. *Contractor-Restricted Access*: Subcontractors only access their assigned defects, preventing cross-visibility of contractual disputes.
- **Competitive Threat Level**: **MEDIUM TO HIGH**.
- **How We Differentiate**:
  - *Lightweight, Rapid Setup*: Calidad Cloud requires weeks of enterprise onboarding and BIM model preparation. Protokol QC starts in 5 minutes with pre-seeded Peruvian protocol templates.
  - *Block-Based PDF Customizer*: Clients design their own official company document formats rather than adopting rigid vendor templates.

---

#### 12. Construnet (Peru / LatAm)
- **Status**: VERIFIED (Traditional construction ERP/budgeting software system).
- **Core Product**: Unit cost analysis (*precios unitarios*), warehouse inventory, public bidding records.
- **Concepts Extracted**:
  1. *Work Breakdown Alignment (Partidas de Obra)*: Connecting quality protocols to standard project budget lines (*partidas*).
- **Competitive Threat Level**: **NEGLIGIBLE** (Legacy desktop/ERP orientation).

---

## 3. Regulatory Domain Note: Peru ITSE
- **Clarification**: Peru's **ITSE (Inspección Técnica de Seguridad en Edificaciones)** is a mandatory municipal regulatory audit conducted by municipal inspectors (under CENEPRED / INDECI guidelines), *not* a commercial software tool.
- **Strategic Decision**: There is no commercial "ITSE-PE app" to benchmark. We incorporate standard ITSE safety matrices as pre-configured template options in Protokol QC V2, positioning our platform as the audit-ready record system for municipal inspections.

---

# 1-Page MVP Synthesis (The Blueprint for Phase 1–5)

```
====================================================================================================
                        PROTOKOL QC — PRODUCT ARCHITECTURE SYNTHESIS
====================================================================================================

[POSITIONING]
Option B: "Quality-control and snag-closure platform" (Plataforma de Control de Calidad y Cierre de
Observaciones para Inmobiliarias y Constructoras) with the rapid Field-to-Branded-PDF engine at its core.

[THE BUYER & THE USER]
- Primary Buyer: Gerente de Operaciones / Jefe de Calidad / Residente de Obra / Gerente Técnico Inmobiliario.
- Value Proposition: 
  1. Eliminate 15+ hours/week retyping field notes into Excel and formatting PDFs.
  2. Accelerate ITO approvals and progress release (*liberación de vaciados*).
  3. Close subcontractor snags (*repasos*) with indisputable timestamped photo evidence.
  4. Hand over apartments without client disputes using standardized digital *Actas de Recepción*.

----------------------------------------------------------------------------------------------------
THE 11-STEP END-TO-END CORE MVP USER FLOW
----------------------------------------------------------------------------------------------------
  [1] Admin creates Company & Project -> uploads company logo & brand accent color.
  [2] Admin imports/selects standard Peruvian QC templates (Concrete, Steel, Formwork, Topography, Repasos, Handover).
  [3] Field Engineer selects Project -> Tower/Block -> Floor -> Unit/Area -> Inspection Protocol.
  [4] User completes checklist 100% OFFLINE on low-end Android mobile.
  [5] User captures photos (<300KB auto-compressed, GPS/timestamp stamped), tolerances, notes, and digital signatures.
  [6] Failed checkpoints AUTO-GENERATE "Hallazgos" (Findings/Non-conformities) with photo proof.
  [7] Findings are assigned to Subcontractors with explicit due dates (*plazos de subsanación*).
  [8] Subcontractor views assigned hallazgos, executes work, and submits closure photo evidence.
  [9] Quality Specialist / Residente verifies fix on-site and marks item as "Verificado".
 [10] App generates an official, company-branded PDF (deterministic block layout) on-device instantly.
 [11] PDF is shared in 1 tap directly to the site WhatsApp group / ITO email. Office Dashboard reflects updated metrics.

----------------------------------------------------------------------------------------------------
CORE MVP FEATURE MATRIX (VERSION 1 — 3 TO 6 MONTH SCOPE)
----------------------------------------------------------------------------------------------------
1. Multi-Company SaaS & RBAC:
   - Isolated company tenants.
   - 5 Strict Roles: Admin, Residente/Supervisor, Calidad, Contratista (isolated to own issues), ITO/Cliente (Read-only).
   - Seat and project quota enforcement ready for commercial launch.

2. Peruvian Location Hierarchy:
   - Empresa -> Proyecto -> Torre/Bloque -> Piso/Nivel -> Departamento/Ambiente/Elemento.

3. Protocol Template Builder & Starter Library:
   - Specialized field types: Conforme/No Conforme/NA, Toleranced Numeric Inputs (e.g. Slump 4" ± 1"), Photos, Signatures.
   - Seeded with 4 Peruvian structural protocol families (Concreto, Acero, Encofrado, Topografía) + Acabados/Repasos + Entrega.

4. Offline-First Mobile Engine:
   - Local-first persistence (SQLite / Drift).
   - Idempotent append-only operation queue with automatic background sync upon connectivity.
   - Conflict resolution: Last-writer-wins with tamper-evident audit logs.
   - Background photo compression (<300KB) with optional EXIF stamp.

5. Hallazgos Lifecycle & Overdue Engine:
   - State Machine: Abierto -> En Proceso -> Cerrado con Evidencia -> Verificado.
   - Automatic overdue flags and contractor accountability tracking.

6. Template Studio & Branded Deterministic PDF Generator:
   - Modular blocks: Letterhead/Header, Project Summary, Checklist Results, Hallazgos Table, Photo Evidence Grid, Signatures, Footer.
   - On-device offline rendering + canonical server-side rendering producing pixel-equivalent documents.
   - 1-tap WhatsApp sharing via native mobile share intents.

7. Responsive Web Office Dashboard:
   - Morning KPI view: Pour release status, open vs. resolved findings by contractor, aging charts.

----------------------------------------------------------------------------------------------------
TECHNICAL STACK COMMITMENT
----------------------------------------------------------------------------------------------------
- Mobile Client: Flutter (Dart) mobile app, Android-first (sideloadable APK via WhatsApp link for Peru pilots).
- On-Device Data: SQLite (Drift) + secure storage + WorkManager background sync.
- Web Dashboard: Responsive web (modern clean UI, zero generic AI aesthetics).
- Backend: Node.js + Express + PostgreSQL (Supabase compatible for auth, sync, and storage).
- Deterministic PDF Engine: Unified JSON template specification rendering identically on Flutter (`pdf`) and Node.js.
====================================================================================================
```
