// Starter Library: Peruvian Real-Estate Construction QC Protocols (NTE E.060, E.070)
// Authentic field checks with engineering tolerances, critical gating, and evidence requirements.

const starterTemplates = [
    {
        code: 'PROT-CONC-01',
        family: 'concreto',
        title: 'Protocolo de Vaciado y Control de Concreto Estructural',
        description: 'Liberación de vaciado, control de consistencia (slump/asentamiento), muestreo de probetas cilíndricas y curado según NTE E.060.',
        items: [
            {
                section: 'Verificación Previa al Vaciado',
                code: 'CONC-01',
                question_text: '¿Se cuenta con la autorización formal de la ITO y Residente para iniciar el vaciado?',
                item_type: 'conforme_no_conforme',
                is_critical: 1
            },
            {
                section: 'Verificación Previa al Vaciado',
                code: 'CONC-02',
                question_text: '¿Se verificó la limpieza total del fondo y costados del encofrado (libre de aserrín, alambre y desmoldante sobrante)?',
                item_type: 'conforme_no_conforme',
                is_critical: 1
            },
            {
                section: 'Control en Estado Fresco (Planta y Obra)',
                code: 'CONC-03',
                question_text: 'Asentamiento con Cono de Abrams (Slump medido en obra)',
                item_type: 'numeric_tolerance',
                tolerance_min: 3.5,
                tolerance_max: 5.5,
                unit: 'pulgadas (in)',
                is_critical: 1
            },
            {
                section: 'Control en Estado Fresco (Planta y Obra)',
                code: 'CONC-04',
                question_text: 'Temperatura del concreto en el momento de descarga',
                item_type: 'numeric_tolerance',
                tolerance_min: 10.0,
                tolerance_max: 32.0,
                unit: '°C',
                is_critical: 0
            },
            {
                section: 'Control de Probetas Cilíndricas (Ensayos a la Compresión f\'c)',
                code: 'CONC-05',
                question_text: 'Toma reglamentaria de juego de probetas (mínimo 4 probetas por cada 50 m³ o por día de vaciado) debidamente codificadas y protegidas',
                item_type: 'photo_required',
                is_critical: 1
            },
            {
                section: 'Colocación y Compactación',
                code: 'CONC-06',
                question_text: '¿Se dispone de vibradores de inmersión operativos (mínimo 2 unidades: 1 en uso + 1 de respaldo en sitio)?',
                item_type: 'conforme_no_conforme',
                is_critical: 1
            },
            {
                section: 'Protección y Curado',
                code: 'CONC-07',
                question_text: 'Método y producto de curado especificado (membrana química / arroceras / yute húmedo)',
                item_type: 'text_observation',
                is_critical: 0
            }
        ]
    },
    {
        code: 'PROT-ACER-01',
        family: 'acero',
        title: 'Protocolo de Liberación de Acero de Refuerzo en Elementos Verticales y Horizontales',
        description: 'Inspección de diámetros, espaciamientos, longitudes de traslape, recubrimientos libres y atortolado conforme a planos estructurales.',
        items: [
            {
                section: 'Geometría y Diámetros',
                code: 'ACER-01',
                question_text: '¿La disposición, diámetro y cantidad de varillas longitudinales coinciden exactamente con los planos del Expediente Técnico?',
                item_type: 'conforme_no_conforme',
                is_critical: 1
            },
            {
                section: 'Estribos y Espaciamiento',
                code: 'ACER-02',
                question_text: 'Espaciamiento de estribos en zonas de confinamiento y centro de luz verificado con huincha metálica',
                item_type: 'conforme_no_conforme',
                is_critical: 1
            },
            {
                section: 'Traslapes y Anclajes',
                code: 'ACER-03',
                question_text: 'Longitud de traslape mínima alcanzada para el diámetro predominante',
                item_type: 'numeric_tolerance',
                tolerance_min: 50.0,
                tolerance_max: 95.0,
                unit: 'cm',
                is_critical: 1
            },
            {
                section: 'Recubrimiento Libre',
                code: 'ACER-04',
                question_text: 'Espesor de dados de concreto o separadores plásticos garantizando el recubrimiento especificado (2.0 cm losas / 4.0 cm columnas y vigas)',
                item_type: 'numeric_tolerance',
                tolerance_min: 3.5,
                tolerance_max: 4.5,
                unit: 'cm',
                is_critical: 1
            },
            {
                section: 'Amarre y Fijación',
                code: 'ACER-05',
                question_text: 'Atortolado firme con alambre negro recocido N° 16 sin holguras ni desplazamiento ante tránsito del personal',
                item_type: 'conforme_no_conforme',
                is_critical: 0
            },
            {
                section: 'Evidencia Fotográfica',
                code: 'ACER-06',
                question_text: 'Fotografía panorámica y detalle de nudos estructurales antes de cerrar encofrado',
                item_type: 'photo_required',
                is_critical: 1
            }
        ]
    },
    {
        code: 'PROT-ENCO-01',
        family: 'encofrado',
        title: 'Protocolo de Verticalidad, Niveles y Rigidez de Encofrados',
        description: 'Verificación de aplomado, alineamiento, estanqueidad de juntas, apuntalamiento y tiempos de desencofrado.',
        items: [
            {
                section: 'Aplomado y Verticalidad',
                code: 'ENCO-01',
                question_text: 'Desviación máxima de plomada en caras de columnas/muros (Tolerancia máxima permitida según ACI 117: 6 mm en 3 m)',
                item_type: 'numeric_tolerance',
                tolerance_min: 0.0,
                tolerance_max: 6.0,
                unit: 'mm',
                is_critical: 1
            },
            {
                section: 'Nivelación de Fondo de Vigas y Losas',
                code: 'ENCO-02',
                question_text: 'Verificación de cotas y contra-flecha especificada en losas de luces mayores a 5 m',
                item_type: 'conforme_no_conforme',
                is_critical: 1
            },
            {
                section: 'Rigidez y Arriostramiento',
                code: 'ENCO-03',
                question_text: '¿Los puntales metálicos, diagonales de arriostramiento y tornapuntas están completamente bloqueados y apoyados en bases firmes?',
                item_type: 'conforme_no_conforme',
                is_critical: 1
            },
            {
                section: 'Estanqueidad de Juntas',
                code: 'ENCO-04',
                question_text: 'Sellado de encuentros y juntas con espuma/cinta para evitar pérdida de lechada durante el vibrado',
                item_type: 'conforme_no_conforme',
                is_critical: 0
            },
            {
                section: 'Evidencia',
                code: 'ENCO-05',
                question_text: 'Registro fotográfico del aplomado y sistema de apuntalamiento del elemento',
                item_type: 'photo_required',
                is_critical: 1
            }
        ]
    },
    {
        code: 'PROT-TOPO-01',
        family: 'topografia',
        title: 'Protocolo de Replanteo Topográfico, Ejes y Control de Niveles',
        description: 'Control de cotas de fondo de cimentación, trazo de ejes principales, nivel de falso piso y plomadas de torres.',
        items: [
            {
                section: 'Ejes y Líneas Base',
                code: 'TOPO-01',
                question_text: '¿Se verificó el amarre de coordenadas del BM oficial con estación total o nivel topográfico calibrado?',
                item_type: 'conforme_no_conforme',
                is_critical: 1
            },
            {
                section: 'Control de Cotas',
                code: 'TOPO-02',
                question_text: 'Desviación de nivel de piso terminado (NPT) respecto a la cota del proyecto',
                item_type: 'numeric_tolerance',
                tolerance_min: -3.0,
                tolerance_max: 3.0,
                unit: 'mm',
                is_critical: 1
            },
            {
                section: 'Espesor y Alineamiento',
                code: 'TOPO-03',
                question_text: 'Verificación de verticalidad de shafts y cajas de ascensores de piso a piso',
                item_type: 'conforme_no_conforme',
                is_critical: 1
            },
            {
                section: 'Croquis y Registro',
                code: 'TOPO-04',
                question_text: 'Foto del croquis de replanteo con firmas del topógrafo de obra y residente',
                item_type: 'photo_required',
                is_critical: 1
            }
        ]
    },
    {
        code: 'PROT-ACAB-01',
        family: 'acabados',
        title: 'Lista de Control de Acabados Interiores y Repasos de Calidad',
        description: 'Control de pintura, cerámicos, zócalos, carpintería de madera/aluminio y aparatos sanitarios previo a entrega.',
        items: [
            {
                section: 'Muros y Cielorrasos',
                code: 'ACAB-01',
                question_text: 'Pintura látex / empaste parejo, sin sombras, chorreaduras ni fisuras superficiales',
                item_type: 'conforme_no_conforme',
                is_critical: 0
            },
            {
                section: 'Pisos y Enchapes',
                code: 'ACAB-02',
                question_text: 'Adherencia de cerámicos y porcelanatos (verificación al golpe con martillo de goma, sin sonido hueco)',
                item_type: 'conforme_no_conforme',
                is_critical: 1
            },
            {
                section: 'Pisos y Enchapes',
                code: 'ACAB-03',
                question_text: 'Desnivel y pendientes de ducha hacia sumidero comprobadas con prueba de agua (escurrimiento libre sin empozamiento)',
                item_type: 'conforme_no_conforme',
                is_critical: 1
            },
            {
                section: 'Carpintería y Cerrajería',
                code: 'ACAB-04',
                question_text: 'Puertas abren y cierran suavemente; cerraduras y pestillos con funcionamiento correcto sin rozamiento en marco',
                item_type: 'conforme_no_conforme',
                is_critical: 0
            },
            {
                section: 'Instalaciones y Pruebas',
                code: 'ACAB-05',
                question_text: 'Presión de agua en griferías y descarga de inodoros verificada sin fugas en llaves de paso ni uniones flexibles',
                item_type: 'conforme_no_conforme',
                is_critical: 1
            },
            {
                section: 'Evidencia de Repaso',
                code: 'ACAB-06',
                question_text: 'Registro fotográfico de detalles o repasos pendientes para el contratista de acabados',
                item_type: 'photo_required',
                is_critical: 0
            }
        ]
    },
    {
        code: 'PROT-ENTR-01',
        family: 'recepcion',
        title: 'Acta de Recepción y Conformidad de Departamento / Inmueble',
        description: 'Acta formal de entrega del inmueble con firma digital del propietario/comprador, especialista de post-venta e ITO.',
        items: [
            {
                section: 'Conformidad General de Ambientes',
                code: 'ENTR-01',
                question_text: 'Sala, comedor, dormitorios, cocina y baños se entregan limpios y con acabados terminados al 100%',
                item_type: 'conforme_no_conforme',
                is_critical: 1
            },
            {
                section: 'Entrega de Llaves y Manuales',
                code: 'ENTR-02',
                question_text: 'Se entrega juego completo de llaves maestras, llaves de intercomunicador y Manual del Propietario',
                item_type: 'conforme_no_conforme',
                is_critical: 1
            },
            {
                section: 'Medidores y Servicios',
                code: 'ENTR-03',
                question_text: 'Lectura de medidor de luz y agua al momento de entrega anotada en acta',
                item_type: 'text_observation',
                is_critical: 0
            },
            {
                section: 'Firma de Acta',
                code: 'ENTR-04',
                question_text: 'Firma en pantalla del cliente/comprador aceptando la recepción y conformidad del inmueble',
                item_type: 'conforme_no_conforme',
                is_critical: 1
            }
        ]
    }
];

module.exports = {
    starterTemplates
};
