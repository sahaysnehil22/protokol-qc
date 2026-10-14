# PROTOKOL QC (Perú) 🇵🇪
### Control de Calidad y Protocolos de Liberación en Obra para Inmobiliarias y Constructoras

Protokol QC es una plataforma B2B SaaS *offline-first* diseñada y construida específicamente para el sector inmobiliario y de construcción del Perú. Permite a ingenieros de campo, especialistas de calidad, residentes de obra, supervisores técnicos (ITO) y contratistas registrar inspecciones, verificar tolerancias según la **Norma Técnica Peruana (NTE E.060 / RNE)**, capturar evidencias fotográficas, gestionar hallazgos (snag list) y emitir actas oficiales en PDF con firma digital y compartirlas en un toque por WhatsApp.

---

## 🏗️ Arquitectura de la Solución

```
+-------------------------------------------------------------------------+
|                          PROTOKOL QC ECOSYSTEM                          |
+-------------------------------------------------------------------------+
                                     │
           ┌─────────────────────────┴─────────────────────────┐
           ▼                                                   ▼
┌───────────────────────────┐                       ┌───────────────────────────┐
│     CLIENTE MÓVIL         │                       │      OFFICE DASHBOARD     │
│   (Flutter / Android)     │                       │       (Web Responsive)    │
│                           │                       │                           │
│ • 100% Offline-First      │                       │ • Métricas Matutinas KPI  │
│ • SQLite Local + Outbox   │                       │ • Liberaciones y Vaciados │
│ • Touch Targets >= 48px   │                       │ • Visor de Protocolos PDF │
│ • Generación PDF on-device│                       │ • Estudio de Plantillas   │
│ • Envío directo WhatsApp  │                       │ • Gestión de Hallazgos    │
└─────────────┬─────────────┘                       └─────────────┬─────────────┘
              │                                                   │
              │  REST API / Sync Queue (Idempotente)              │
              └─────────────────────────┬─────────────────────────┘
                                        ▼
                        ┌───────────────────────────┐
                        │       BACKEND API         │
                        │    (Node.js / Express)    │
                        │                           │
                        │ • SQLite con WAL Mode     │
                        │ • Autenticación JWT / RBAC│
                        │ • Motor PDF Determinista  │
                        │ • Trazabilidad y Auditoría│
                        └───────────────────────────┘
```

---

## 📋 Flujo Central de 11 Pasos (Core User Journey)

1. **Configuración de Obra:** El residente o administrador selecciona el proyecto activo (*Edificio Residencial Las Palmeras de Miraflores*).
2. **Selección de Plantilla Técnica:** Catálogo de partidas conforme a normas peruanas (*Vaciado de Concreto NTE E.060*, *Acero de Refuerzo*, *Encofrado*, *Topografía*, *Repasos de Pintura* y *Acta de Entrega*).
3. **Selección Jerárquica de Ubicación:** Selección por árbol en obra: `Torre A > Piso 2 > Placa PL-01 / Dpto 201`.
4. **Inspección Offline en Campo:** Inspección en modo avión sin conexión a internet.
5. **Verificación de Tolerancias y Fotos:** Controles táctiles de alta visibilidad para sol directo (mínimo 48px) con botones segmentados: `CONFORME`, `NO CONFORME` y `N/A`. Validación en tiempo real de rangos numéricos (ej. Asentamiento / Slump: 3.0 - 5.0 in).
6. **Promoción Automática a Hallazgos:** Cualquier ítem marcado como `NO CONFORME` genera automáticamente un *Hallazgo* (*non-conformity / snag*) con código único (ej. `HAL-2026-0042`).
7. **Asignación a Contratista:** El hallazgo se asigna a la especialidad correspondiente (*Fierrería*, *Encofrado*, *Acabados*) con fecha límite de subsanación.
8. **Subsanación con Evidencia Obligatoria:** El contratista sube la fotografía de la reparación y las notas técnicas; el sistema prohíbe el cierre sin evidencia fotográfica.
9. **Verificación y Cierre por Calidad:** El especialista de calidad o residente inspecciona la evidencia y aprueba o rechaza el trabajo.
10. **Generación Determinista de PDF:** Emisión de acta técnica oficial de liberación con diseño corporativo, tolerancias y casillas de firma.
11. **Compartir en 1 Toque por WhatsApp:** Envío del PDF y resumen del acta directamente al grupo de WhatsApp de obra o a la supervisión técnica (ITO).

---

## 🔒 Roles y Credenciales Semilla (Seed Demo)

Contraseña universal para todas las cuentas de demostración: `Protokol2026!`

| Rol en Obra | Usuario / Correo | Nombre | Responsabilidad |
|-------------|------------------|--------|-----------------|
| **Especialista de Calidad** | `calidad@sanmartin.pe` | Ing. Daniel Vargas | Liberaciones de partidas, levantamiento de hallazgos y verificación técnica |
| **Residente de Obra** | `residente@sanmartin.pe` | Ing. Carlos Mendoza (CIP 84920) | Aprobación final, cuaderno de obra y control de cronograma |
| **Contratista Estructuras** | `contratista.estructuras@subcon.pe` | Carlos Subcon | Subsanación de acero y encofrados (vista aislada de hallazgos) |
| **Contratista Acabados** | `contratista.acabados@subcon.pe` | Jorge Acabados | Subsanación de pintura, drywall y porcelanato |
| **Supervisor Técnico (ITO)** | `ito@supervisorape.com` | Ing. Patricia Thorne (CIP 63102) | Auditoría externa para la entidad financiera o inmobiliaria |
| **Administrador** | `admin@sanmartin.pe` | Administrador General | Gestión de proyectos, usuarios y estudio de plantillas |

---

## 🚀 Guía de Ejecución Local

### Prerrequisitos
- **Node.js** (v18 o superior)
- **Flutter SDK** (v3.13 o superior con Dart 3)

### 1. Iniciar el Servidor Backend & Web Dashboard
```bash
cd backend
npm install
node src/seed.js   # Siembra inicial de datos para Edificio Las Palmeras
node src/server.js # Inicia en http://localhost:4000
```
- **API REST:** `http://localhost:4000/api`
- **Dashboard Web:** `http://localhost:4000`
- **Health Check:** `http://localhost:4000/api/health`

### 2. Ejecutar Pruebas Automatizadas del Backend
```bash
cd backend
npm test
```
*8 de 8 suites de prueba pasando (100% green).*

### 3. Ejecutar y Probar la Aplicación Móvil Flutter
```bash
cd mobile
flutter pub get
flutter analyze  # 0 warnings, 0 issues
flutter test     # Validación de modelos y lógica de tolerancias
flutter run -d chrome  # O en emulador Android: flutter run -d android
```

---

## 📐 Conformidad Normativa y Clean-Room IP
- **Clean-Room Enforcement:** Código fuente, esquemas y diseño visual 100% originales.
- **Normativa Técnica Peruana:**
  - **NTE E.060 (Concreto Armado):** Ensayos de slump (ASTM C143), recubrimientos mínimos de armaduras y muestreo de probetas (ASTM C31/C39).
  - **NTE G.050 (Seguridad durante la Construcción):** Criterios de orden y limpieza en frentes de vaciado.
  - **Reglamento Nacional de Edificaciones (RNE):** Estructura jerárquica de actas de recepción de departamentos y áreas comunes.

---

© 2026 Inmobiliaria & Constructora San Martín S.A.C. / Protokol QC. Todos los derechos reservados.
