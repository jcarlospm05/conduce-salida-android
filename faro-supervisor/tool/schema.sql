-- Generated SQLite schema. No live data or secrets.
PRAGMA foreign_keys=ON;

CREATE TABLE "PM_Roles" (
  "ID" INTEGER PRIMARY KEY AUTOINCREMENT,
  "CodigoRol" TEXT NOT NULL,
  "NombreRol" TEXT NOT NULL,
  "Activo" INTEGER NOT NULL DEFAULT 0 CHECK ("Activo" IN (0,1)),
  UNIQUE ("CodigoRol")
);

CREATE TABLE "PM_Usuarios" (
  "ID" INTEGER PRIMARY KEY AUTOINCREMENT,
  "UPN" TEXT NOT NULL,
  "NombreMostrado" TEXT NOT NULL,
  "RolID" INTEGER NOT NULL CHECK ("RolID" IS NULL OR (typeof("RolID")='integer' AND "RolID">=0)),
  "Activo" INTEGER NOT NULL DEFAULT 0 CHECK ("Activo" IN (0,1)),
  "AltaUTC" TEXT NOT NULL,
  "BajaUTC" TEXT,
  FOREIGN KEY ("RolID") REFERENCES "PM_Roles"("ID") ON DELETE RESTRICT,
  UNIQUE ("UPN")
);

CREATE TABLE "PM_Credenciales" (
  "ID" INTEGER PRIMARY KEY AUTOINCREMENT,
  "UsuarioID" INTEGER NOT NULL CHECK ("UsuarioID" IS NULL OR (typeof("UsuarioID")='integer' AND "UsuarioID">=0)),
  "HashPIN" TEXT,
  "SaltPIN" TEXT,
  "Iteraciones" INTEGER CHECK ("Iteraciones" IS NULL OR (typeof("Iteraciones")='integer' AND "Iteraciones">=0)),
  "ForzarCambio" INTEGER NOT NULL DEFAULT 0 CHECK ("ForzarCambio" IN (0,1)),
  "ActualizacionUTC" TEXT NOT NULL,
  FOREIGN KEY ("UsuarioID") REFERENCES "PM_Usuarios"("ID") ON DELETE RESTRICT
);

CREATE TABLE "PM_Equipos" (
  "ID" INTEGER PRIMARY KEY AUTOINCREMENT,
  "InstalacionGUID" TEXT NOT NULL,
  "UsuarioID" INTEGER NOT NULL CHECK ("UsuarioID" IS NULL OR (typeof("UsuarioID")='integer' AND "UsuarioID">=0)),
  "EquipoEtiqueta" TEXT NOT NULL,
  "RegistradoUTC" TEXT NOT NULL,
  "Activo" INTEGER NOT NULL DEFAULT 0 CHECK ("Activo" IN (0,1)),
  "VerificadoPorID" INTEGER CHECK ("VerificadoPorID" IS NULL OR (typeof("VerificadoPorID")='integer' AND "VerificadoPorID">=0)),
  FOREIGN KEY ("UsuarioID") REFERENCES "PM_Usuarios"("ID") ON DELETE RESTRICT,
  FOREIGN KEY ("VerificadoPorID") REFERENCES "PM_Usuarios"("ID") ON DELETE RESTRICT,
  UNIQUE ("InstalacionGUID")
);

CREATE TABLE "PM_Buques" (
  "ID" INTEGER PRIMARY KEY AUTOINCREMENT,
  "NombreBuque" TEXT NOT NULL,
  "IMO" TEXT,
  "Activo" INTEGER NOT NULL DEFAULT 0 CHECK ("Activo" IN (0,1))
);

CREATE TABLE "PM_Escalas" (
  "ID" INTEGER PRIMARY KEY AUTOINCREMENT,
  "CallKey" TEXT NOT NULL,
  "BuqueID" INTEGER NOT NULL CHECK ("BuqueID" IS NULL OR (typeof("BuqueID")='integer' AND "BuqueID">=0)),
  "Viaje" TEXT,
  "FechaETA" TEXT NOT NULL,
  "ETBUTC" TEXT,
  "ETDUTC" TEXT,
  "Muelle" TEXT,
  "EstadoProyecto" TEXT NOT NULL DEFAULT 'Pendiente',
  "InicioRealUTC" TEXT,
  "FinRealUTC" TEXT,
  "FechaCierreUTC" TEXT,
  "CerradoPorID" INTEGER CHECK ("CerradoPorID" IS NULL OR (typeof("CerradoPorID")='integer' AND "CerradoPorID">=0)),
  "NotaGeneral" TEXT,
  "ServicioID" INTEGER CHECK ("ServicioID" IS NULL OR (typeof("ServicioID")='integer' AND "ServicioID">=0)),
  "AgenteID" INTEGER CHECK ("AgenteID" IS NULL OR (typeof("AgenteID")='integer' AND "AgenteID">=0)),
  "ETACompletaUTC" TEXT,
  "FinalizadaRevisionUTC" TEXT,
  "FechaInicioPlanUTC" TEXT,
  "LimiteInicioPlanUTC" TEXT,
  "HoraLimiteFinUTC" TEXT,
  "HoraLimiteOriginalUTC" TEXT,
  "VersionProyecto" INTEGER NOT NULL DEFAULT 0 CHECK ("VersionProyecto" IS NULL OR (typeof("VersionProyecto")='integer' AND "VersionProyecto">=0)),
  FOREIGN KEY ("BuqueID") REFERENCES "PM_Buques"("ID") ON DELETE RESTRICT,
  FOREIGN KEY ("CerradoPorID") REFERENCES "PM_Usuarios"("ID") ON DELETE RESTRICT,
  FOREIGN KEY ("ServicioID") REFERENCES "PM_Servicios"("ID") ON DELETE RESTRICT,
  FOREIGN KEY ("AgenteID") REFERENCES "PM_Agentes"("ID") ON DELETE RESTRICT,
  UNIQUE ("CallKey")
);

CREATE TABLE "PM_ETA_Historial" (
  "ID" INTEGER PRIMARY KEY AUTOINCREMENT,
  "EscalaID" INTEGER NOT NULL CHECK ("EscalaID" IS NULL OR (typeof("EscalaID")='integer' AND "EscalaID">=0)),
  "AnteriorFechaETA" TEXT,
  "NuevaFechaETA" TEXT NOT NULL,
  "Motivo" TEXT,
  "ActorID" INTEGER NOT NULL CHECK ("ActorID" IS NULL OR (typeof("ActorID")='integer' AND "ActorID">=0)),
  "FechaUTC" TEXT NOT NULL,
  "AnteriorETACompletaUTC" TEXT,
  "NuevaETACompletaUTC" TEXT,
  FOREIGN KEY ("EscalaID") REFERENCES "PM_Escalas"("ID") ON DELETE RESTRICT,
  FOREIGN KEY ("ActorID") REFERENCES "PM_Usuarios"("ID") ON DELETE RESTRICT
);

CREATE TABLE "PM_Asignaciones" (
  "ID" INTEGER PRIMARY KEY AUTOINCREMENT,
  "EscalaID" INTEGER NOT NULL CHECK ("EscalaID" IS NULL OR (typeof("EscalaID")='integer' AND "EscalaID">=0)),
  "UsuarioID" INTEGER NOT NULL CHECK ("UsuarioID" IS NULL OR (typeof("UsuarioID")='integer' AND "UsuarioID">=0)),
  "TipoParticipacion" TEXT NOT NULL,
  "Vigente" INTEGER NOT NULL DEFAULT 0 CHECK ("Vigente" IN (0,1)),
  "AsignadoPorID" INTEGER NOT NULL CHECK ("AsignadoPorID" IS NULL OR (typeof("AsignadoPorID")='integer' AND "AsignadoPorID">=0)),
  "AsignadoUTC" TEXT NOT NULL,
  "FinAsignacionUTC" TEXT,
  FOREIGN KEY ("EscalaID") REFERENCES "PM_Escalas"("ID") ON DELETE RESTRICT,
  FOREIGN KEY ("UsuarioID") REFERENCES "PM_Usuarios"("ID") ON DELETE RESTRICT,
  FOREIGN KEY ("AsignadoPorID") REFERENCES "PM_Usuarios"("ID") ON DELETE RESTRICT
);

CREATE TABLE "PM_ControlEdicion" (
  "ID" INTEGER PRIMARY KEY AUTOINCREMENT,
  "EscalaID" INTEGER NOT NULL CHECK ("EscalaID" IS NULL OR (typeof("EscalaID")='integer' AND "EscalaID">=0)),
  "EstadoBloqueo" TEXT NOT NULL DEFAULT 'Libre',
  "TitularUsuarioID" INTEGER CHECK ("TitularUsuarioID" IS NULL OR (typeof("TitularUsuarioID")='integer' AND "TitularUsuarioID">=0)),
  "SesionTrabajoID" INTEGER CHECK ("SesionTrabajoID" IS NULL OR (typeof("SesionTrabajoID")='integer' AND "SesionTrabajoID">=0)),
  "UltimoCambioUTC" TEXT NOT NULL,
  "VersionControl" INTEGER NOT NULL DEFAULT 1 CHECK ("VersionControl" IS NULL OR (typeof("VersionControl")='integer' AND "VersionControl">=0)),
  FOREIGN KEY ("EscalaID") REFERENCES "PM_Escalas"("ID") ON DELETE RESTRICT,
  FOREIGN KEY ("TitularUsuarioID") REFERENCES "PM_Usuarios"("ID") ON DELETE RESTRICT,
  FOREIGN KEY ("SesionTrabajoID") REFERENCES "PM_SesionesTrabajo"("ID") ON DELETE RESTRICT,
  UNIQUE ("EscalaID")
);

CREATE TABLE "PM_SesionesTrabajo" (
  "ID" INTEGER PRIMARY KEY AUTOINCREMENT,
  "EscalaID" INTEGER NOT NULL CHECK ("EscalaID" IS NULL OR (typeof("EscalaID")='integer' AND "EscalaID">=0)),
  "UsuarioID" INTEGER NOT NULL CHECK ("UsuarioID" IS NULL OR (typeof("UsuarioID")='integer' AND "UsuarioID">=0)),
  "EquipoID" INTEGER NOT NULL CHECK ("EquipoID" IS NULL OR (typeof("EquipoID")='integer' AND "EquipoID">=0)),
  "InicioUTC" TEXT NOT NULL,
  "FinUTC" TEXT,
  "FinTipo" TEXT,
  "Observacion" TEXT,
  FOREIGN KEY ("EscalaID") REFERENCES "PM_Escalas"("ID") ON DELETE RESTRICT,
  FOREIGN KEY ("UsuarioID") REFERENCES "PM_Usuarios"("ID") ON DELETE RESTRICT,
  FOREIGN KEY ("EquipoID") REFERENCES "PM_Equipos"("ID") ON DELETE RESTRICT
);

CREATE TABLE "PM_CatalogoTareas" (
  "ID" INTEGER PRIMARY KEY AUTOINCREMENT,
  "CodigoTarea" TEXT NOT NULL,
  "Seccion" TEXT NOT NULL,
  "NombreTarea" TEXT NOT NULL,
  "Orden" INTEGER NOT NULL CHECK ("Orden" IS NULL OR (typeof("Orden")='integer' AND "Orden">=0)),
  "ObligatoriaDefecto" INTEGER NOT NULL DEFAULT 0 CHECK ("ObligatoriaDefecto" IN (0,1)),
  "CondicionAplica" TEXT,
  "Activa" INTEGER NOT NULL DEFAULT 0 CHECK ("Activa" IN (0,1))
);

CREATE TABLE "PM_TareasProyecto" (
  "ID" INTEGER PRIMARY KEY AUTOINCREMENT,
  "EscalaID" INTEGER NOT NULL CHECK ("EscalaID" IS NULL OR (typeof("EscalaID")='integer' AND "EscalaID">=0)),
  "CatalogoTareaID" INTEGER CHECK ("CatalogoTareaID" IS NULL OR (typeof("CatalogoTareaID")='integer' AND "CatalogoTareaID">=0)),
  "EsEspecial" INTEGER NOT NULL DEFAULT 0 CHECK ("EsEspecial" IN (0,1)),
  "TextoTarea" TEXT NOT NULL,
  "Seccion" TEXT NOT NULL,
  "Obligatoria" INTEGER NOT NULL DEFAULT 0 CHECK ("Obligatoria" IN (0,1)),
  "Aplica" INTEGER NOT NULL DEFAULT 0 CHECK ("Aplica" IN (0,1)),
  "EstadoTarea" TEXT NOT NULL DEFAULT 'Pendiente',
  "VenceUTC" TEXT,
  "CreadaPorID" INTEGER NOT NULL CHECK ("CreadaPorID" IS NULL OR (typeof("CreadaPorID")='integer' AND "CreadaPorID">=0)),
  "CreadaUTC" TEXT NOT NULL,
  "RealizadaPorID" INTEGER CHECK ("RealizadaPorID" IS NULL OR (typeof("RealizadaPorID")='integer' AND "RealizadaPorID">=0)),
  "RealizadaUTC" TEXT,
  "Observacion" TEXT,
  FOREIGN KEY ("EscalaID") REFERENCES "PM_Escalas"("ID") ON DELETE RESTRICT,
  FOREIGN KEY ("CatalogoTareaID") REFERENCES "PM_CatalogoTareas"("ID") ON DELETE RESTRICT,
  FOREIGN KEY ("CreadaPorID") REFERENCES "PM_Usuarios"("ID") ON DELETE RESTRICT,
  FOREIGN KEY ("RealizadaPorID") REFERENCES "PM_Usuarios"("ID") ON DELETE RESTRICT
);

CREATE TABLE "PM_Estimados" (
  "ID" INTEGER PRIMARY KEY AUTOINCREMENT,
  "EscalaID" INTEGER NOT NULL CHECK ("EscalaID" IS NULL OR (typeof("EscalaID")='integer' AND "EscalaID">=0)),
  "ImpFull" INTEGER NOT NULL DEFAULT 0 CHECK ("ImpFull" IS NULL OR (typeof("ImpFull")='integer' AND "ImpFull">=0)),
  "ImpVacios" INTEGER NOT NULL DEFAULT 0 CHECK ("ImpVacios" IS NULL OR (typeof("ImpVacios")='integer' AND "ImpVacios">=0)),
  "ImpEslingados" INTEGER NOT NULL DEFAULT 0 CHECK ("ImpEslingados" IS NULL OR (typeof("ImpEslingados")='integer' AND "ImpEslingados">=0)),
  "ImpEspecial" INTEGER NOT NULL DEFAULT 0 CHECK ("ImpEspecial" IS NULL OR (typeof("ImpEspecial")='integer' AND "ImpEspecial">=0)),
  "ExpFull" INTEGER NOT NULL DEFAULT 0 CHECK ("ExpFull" IS NULL OR (typeof("ExpFull")='integer' AND "ExpFull">=0)),
  "ExpVacios" INTEGER NOT NULL DEFAULT 0 CHECK ("ExpVacios" IS NULL OR (typeof("ExpVacios")='integer' AND "ExpVacios">=0)),
  "ExpEslingados" INTEGER NOT NULL DEFAULT 0 CHECK ("ExpEslingados" IS NULL OR (typeof("ExpEslingados")='integer' AND "ExpEslingados">=0)),
  "ExpEspecial" INTEGER NOT NULL DEFAULT 0 CHECK ("ExpEspecial" IS NULL OR (typeof("ExpEspecial")='integer' AND "ExpEspecial">=0)),
  "MovTapas" INTEGER NOT NULL DEFAULT 0 CHECK ("MovTapas" IS NULL OR (typeof("MovTapas")='integer' AND "MovTapas">=0)),
  "MovDama" INTEGER NOT NULL DEFAULT 0 CHECK ("MovDama" IS NULL OR (typeof("MovDama")='integer' AND "MovDama">=0)),
  "MovCapones" INTEGER NOT NULL DEFAULT 0 CHECK ("MovCapones" IS NULL OR (typeof("MovCapones")='integer' AND "MovCapones">=0)),
  "MovOtros" INTEGER NOT NULL DEFAULT 0 CHECK ("MovOtros" IS NULL OR (typeof("MovOtros")='integer' AND "MovOtros">=0)),
  "CuadrillasPrevistas" INTEGER CHECK ("CuadrillasPrevistas" IS NULL OR (typeof("CuadrillasPrevistas")='integer' AND "CuadrillasPrevistas">=0)),
  "ProductividadMeta" REAL CHECK ("ProductividadMeta" IS NULL OR (typeof("ProductividadMeta") IN ('real','integer') AND "ProductividadMeta">=0)),
  "HorasEstimadas" REAL CHECK ("HorasEstimadas" IS NULL OR (typeof("HorasEstimadas") IN ('real','integer') AND "HorasEstimadas">=0)),
  "InicioPrevistoUTC" TEXT,
  "Notas" TEXT,
  "ExpSeaCarrierVacios" INTEGER CHECK ("ExpSeaCarrierVacios" IS NULL OR (typeof("ExpSeaCarrierVacios")='integer' AND "ExpSeaCarrierVacios">=0)),
  "ExpGensetChassis" INTEGER CHECK ("ExpGensetChassis" IS NULL OR (typeof("ExpGensetChassis")='integer' AND "ExpGensetChassis">=0)),
  "RestowsBajan" INTEGER NOT NULL DEFAULT 0 CHECK ("RestowsBajan" IS NULL OR (typeof("RestowsBajan")='integer' AND "RestowsBajan">=0)),
  "RestowsSuben" INTEGER NOT NULL DEFAULT 0 CHECK ("RestowsSuben" IS NULL OR (typeof("RestowsSuben")='integer' AND "RestowsSuben">=0)),
  "MovChasis" INTEGER CHECK ("MovChasis" IS NULL OR (typeof("MovChasis")='integer' AND "MovChasis">=0)),
  "EstimadoCerrado" INTEGER NOT NULL DEFAULT 0 CHECK ("EstimadoCerrado" IN (0,1)),
  "CongeladoUTC" TEXT,
  "ProductividadEstimadaBuque" REAL CHECK ("ProductividadEstimadaBuque" IS NULL OR (typeof("ProductividadEstimadaBuque") IN ('real','integer') AND "ProductividadEstimadaBuque">=0)),
  "ETCEstimadoUTC" TEXT,
  FOREIGN KEY ("EscalaID") REFERENCES "PM_Escalas"("ID") ON DELETE RESTRICT,
  UNIQUE ("EscalaID")
);

CREATE TABLE "PM_VaciosDestino" (
  "ID" INTEGER PRIMARY KEY AUTOINCREMENT,
  "EscalaID" INTEGER NOT NULL CHECK ("EscalaID" IS NULL OR (typeof("EscalaID")='integer' AND "EscalaID">=0)),
  "PuertoDestino" TEXT NOT NULL,
  "Cantidad" INTEGER NOT NULL CHECK ("Cantidad" IS NULL OR (typeof("Cantidad")='integer' AND "Cantidad">=0)),
  "Nota" TEXT,
  "PuertoID" INTEGER CHECK ("PuertoID" IS NULL OR (typeof("PuertoID")='integer' AND "PuertoID">=0)),
  "TipoEquipo" TEXT,
  FOREIGN KEY ("EscalaID") REFERENCES "PM_Escalas"("ID") ON DELETE RESTRICT,
  FOREIGN KEY ("PuertoID") REFERENCES "PM_Puertos"("ID") ON DELETE RESTRICT
);

CREATE TABLE "PM_Hourly" (
  "ID" INTEGER PRIMARY KEY AUTOINCREMENT,
  "EscalaID" INTEGER NOT NULL CHECK ("EscalaID" IS NULL OR (typeof("EscalaID")='integer' AND "EscalaID">=0)),
  "HoraInicioUTC" TEXT NOT NULL,
  "MovImp" INTEGER NOT NULL DEFAULT 0 CHECK ("MovImp" IS NULL OR (typeof("MovImp")='integer' AND "MovImp">=0)),
  "ActualizadoPorID" INTEGER NOT NULL CHECK ("ActualizadoPorID" IS NULL OR (typeof("ActualizadoPorID")='integer' AND "ActualizadoPorID">=0)),
  "ActualizadoUTC" TEXT NOT NULL,
  "HoraFinUTC" TEXT NOT NULL,
  "ClaveEscalaIntervalo" TEXT NOT NULL,
  "ExpFull" INTEGER NOT NULL CHECK ("ExpFull" IS NULL OR (typeof("ExpFull")='integer' AND "ExpFull">=0)),
  "ExpVacio" INTEGER NOT NULL CHECK ("ExpVacio" IS NULL OR (typeof("ExpVacio")='integer' AND "ExpVacio">=0)),
  "RestowDown" INTEGER NOT NULL CHECK ("RestowDown" IS NULL OR (typeof("RestowDown")='integer' AND "RestowDown">=0)),
  "RestowUp" INTEGER NOT NULL CHECK ("RestowUp" IS NULL OR (typeof("RestowUp")='integer' AND "RestowUp">=0)),
  "MovTapas" INTEGER NOT NULL CHECK ("MovTapas" IS NULL OR (typeof("MovTapas")='integer' AND "MovTapas">=0)),
  "MovEspeciales" INTEGER CHECK ("MovEspeciales" IS NULL OR (typeof("MovEspeciales")='integer' AND "MovEspeciales">=0)),
  "NotaHora" TEXT,
  "PerdidaHoras" INTEGER NOT NULL CHECK ("PerdidaHoras" IS NULL OR (typeof("PerdidaHoras")='integer' AND "PerdidaHoras">=0)),
  "PerdidaMinutos" INTEGER NOT NULL CHECK ("PerdidaMinutos" IS NULL OR (typeof("PerdidaMinutos")='integer' AND "PerdidaMinutos">=0)),
  "ProductividadCorte" REAL CHECK ("ProductividadCorte" IS NULL OR (typeof("ProductividadCorte") IN ('real','integer') AND "ProductividadCorte">=0)),
  "ETCProyectadoUTC" TEXT,
  "EstadoValidacion" TEXT,
  FOREIGN KEY ("EscalaID") REFERENCES "PM_Escalas"("ID") ON DELETE RESTRICT,
  FOREIGN KEY ("ActualizadoPorID") REFERENCES "PM_Usuarios"("ID") ON DELETE RESTRICT,
  UNIQUE ("ClaveEscalaIntervalo")
);

CREATE TABLE "PM_Eventos" (
  "ID" INTEGER PRIMARY KEY AUTOINCREMENT,
  "EscalaID" INTEGER CHECK ("EscalaID" IS NULL OR (typeof("EscalaID")='integer' AND "EscalaID">=0)),
  "ActorID" INTEGER NOT NULL CHECK ("ActorID" IS NULL OR (typeof("ActorID")='integer' AND "ActorID">=0)),
  "EquipoID" INTEGER CHECK ("EquipoID" IS NULL OR (typeof("EquipoID")='integer' AND "EquipoID">=0)),
  "SesionTrabajoID" INTEGER CHECK ("SesionTrabajoID" IS NULL OR (typeof("SesionTrabajoID")='integer' AND "SesionTrabajoID">=0)),
  "FechaUTC" TEXT NOT NULL,
  "EventoCodigo" TEXT NOT NULL,
  "Entidad" TEXT,
  "RegistroID" INTEGER CHECK ("RegistroID" IS NULL OR (typeof("RegistroID")='integer' AND "RegistroID">=0)),
  "Antes" TEXT,
  "Despues" TEXT,
  "Resultado" TEXT NOT NULL,
  "Origen" TEXT NOT NULL,
  "TipoEvento" TEXT,
  "RequiereAuditoria" INTEGER NOT NULL DEFAULT 0 CHECK ("RequiereAuditoria" IN (0,1)),
  "CorrelacionGUID" TEXT,
  FOREIGN KEY ("EscalaID") REFERENCES "PM_Escalas"("ID") ON DELETE RESTRICT,
  FOREIGN KEY ("ActorID") REFERENCES "PM_Usuarios"("ID") ON DELETE RESTRICT,
  FOREIGN KEY ("EquipoID") REFERENCES "PM_Equipos"("ID") ON DELETE RESTRICT,
  FOREIGN KEY ("SesionTrabajoID") REFERENCES "PM_SesionesTrabajo"("ID") ON DELETE RESTRICT
);

CREATE TABLE "PM_Relevos" (
  "ID" INTEGER PRIMARY KEY AUTOINCREMENT,
  "EscalaID" INTEGER NOT NULL CHECK ("EscalaID" IS NULL OR (typeof("EscalaID")='integer' AND "EscalaID">=0)),
  "SaleUsuarioID" INTEGER NOT NULL CHECK ("SaleUsuarioID" IS NULL OR (typeof("SaleUsuarioID")='integer' AND "SaleUsuarioID">=0)),
  "EntraUsuarioID" INTEGER CHECK ("EntraUsuarioID" IS NULL OR (typeof("EntraUsuarioID")='integer' AND "EntraUsuarioID">=0)),
  "PausaUTC" TEXT NOT NULL,
  "TomaUTC" TEXT,
  "NotaEntrega" TEXT,
  FOREIGN KEY ("EscalaID") REFERENCES "PM_Escalas"("ID") ON DELETE RESTRICT,
  FOREIGN KEY ("SaleUsuarioID") REFERENCES "PM_Usuarios"("ID") ON DELETE RESTRICT,
  FOREIGN KEY ("EntraUsuarioID") REFERENCES "PM_Usuarios"("ID") ON DELETE RESTRICT
);

CREATE TABLE "PM_Revisiones" (
  "ID" INTEGER PRIMARY KEY AUTOINCREMENT,
  "EscalaID" INTEGER NOT NULL CHECK ("EscalaID" IS NULL OR (typeof("EscalaID")='integer' AND "EscalaID">=0)),
  "GerenteID" INTEGER NOT NULL CHECK ("GerenteID" IS NULL OR (typeof("GerenteID")='integer' AND "GerenteID">=0)),
  "Decision" TEXT NOT NULL,
  "Observacion" TEXT,
  "FechaUTC" TEXT NOT NULL,
  FOREIGN KEY ("EscalaID") REFERENCES "PM_Escalas"("ID") ON DELETE RESTRICT,
  FOREIGN KEY ("GerenteID") REFERENCES "PM_Usuarios"("ID") ON DELETE RESTRICT
);

CREATE TABLE "PM_Criterios" (
  "ID" INTEGER PRIMARY KEY AUTOINCREMENT,
  "CodigoCriterio" TEXT NOT NULL,
  "Nombre" TEXT NOT NULL,
  "Peso" REAL NOT NULL CHECK ("Peso" IS NULL OR (typeof("Peso") IN ('real','integer') AND "Peso">=0)),
  "Activo" INTEGER NOT NULL DEFAULT 0 CHECK ("Activo" IN (0,1))
);

CREATE TABLE "PM_Evaluaciones" (
  "ID" INTEGER PRIMARY KEY AUTOINCREMENT,
  "EscalaID" INTEGER NOT NULL CHECK ("EscalaID" IS NULL OR (typeof("EscalaID")='integer' AND "EscalaID">=0)),
  "AuditorID" INTEGER NOT NULL CHECK ("AuditorID" IS NULL OR (typeof("AuditorID")='integer' AND "AuditorID">=0)),
  "CriterioID" INTEGER NOT NULL CHECK ("CriterioID" IS NULL OR (typeof("CriterioID")='integer' AND "CriterioID">=0)),
  "Puntuacion" REAL NOT NULL CHECK ("Puntuacion" IS NULL OR (typeof("Puntuacion") IN ('real','integer') AND "Puntuacion">=0)),
  "GerenteID" INTEGER NOT NULL CHECK ("GerenteID" IS NULL OR (typeof("GerenteID")='integer' AND "GerenteID">=0)),
  "FechaUTC" TEXT NOT NULL,
  "Comentario" TEXT,
  FOREIGN KEY ("EscalaID") REFERENCES "PM_Escalas"("ID") ON DELETE RESTRICT,
  FOREIGN KEY ("AuditorID") REFERENCES "PM_Usuarios"("ID") ON DELETE RESTRICT,
  FOREIGN KEY ("CriterioID") REFERENCES "PM_Criterios"("ID") ON DELETE RESTRICT,
  FOREIGN KEY ("GerenteID") REFERENCES "PM_Usuarios"("ID") ON DELETE RESTRICT
);

CREATE TABLE "PM_PermisosRol" (
  "ID" INTEGER PRIMARY KEY AUTOINCREMENT,
  "RolID" INTEGER NOT NULL CHECK ("RolID" IS NULL OR (typeof("RolID")='integer' AND "RolID">=0)),
  "CodigoPermiso" TEXT NOT NULL,
  "Habilitado" INTEGER NOT NULL DEFAULT 0 CHECK ("Habilitado" IN (0,1)),
  "ModificadoPorID" INTEGER NOT NULL CHECK ("ModificadoPorID" IS NULL OR (typeof("ModificadoPorID")='integer' AND "ModificadoPorID">=0)),
  "ModificadoUTC" TEXT NOT NULL,
  FOREIGN KEY ("RolID") REFERENCES "PM_Roles"("ID") ON DELETE RESTRICT,
  FOREIGN KEY ("ModificadoPorID") REFERENCES "PM_Usuarios"("ID") ON DELETE RESTRICT,
  UNIQUE ("RolID","CodigoPermiso")
);

CREATE TABLE "PM_Servicios" (
  "ID" INTEGER PRIMARY KEY AUTOINCREMENT,
  "CodigoServicio" TEXT NOT NULL,
  "NombreServicio" TEXT NOT NULL,
  "VarianteCall" TEXT,
  "AnticipacionHoras" INTEGER NOT NULL DEFAULT 48 CHECK ("AnticipacionHoras" IS NULL OR (typeof("AnticipacionHoras")='integer' AND "AnticipacionHoras">=0)),
  "Activo" INTEGER NOT NULL DEFAULT 0 CHECK ("Activo" IN (0,1))
);

CREATE TABLE "PM_Agentes" (
  "ID" INTEGER PRIMARY KEY AUTOINCREMENT,
  "NombreAgente" TEXT NOT NULL,
  "Activo" INTEGER NOT NULL DEFAULT 0 CHECK ("Activo" IN (0,1))
);

CREATE TABLE "PM_Puertos" (
  "ID" INTEGER PRIMARY KEY AUTOINCREMENT,
  "CodigoPuerto" TEXT,
  "NombrePuerto" TEXT NOT NULL,
  "Pais" TEXT
);

CREATE TABLE "PM_RutasServicio" (
  "ID" INTEGER PRIMARY KEY AUTOINCREMENT,
  "ServicioID" INTEGER NOT NULL CHECK ("ServicioID" IS NULL OR (typeof("ServicioID")='integer' AND "ServicioID">=0)),
  "PuertoID" INTEGER NOT NULL CHECK ("PuertoID" IS NULL OR (typeof("PuertoID")='integer' AND "PuertoID">=0)),
  "Secuencia" INTEGER NOT NULL CHECK ("Secuencia" IS NULL OR (typeof("Secuencia")='integer' AND "Secuencia">=0)),
  FOREIGN KEY ("ServicioID") REFERENCES "PM_Servicios"("ID") ON DELETE RESTRICT,
  FOREIGN KEY ("PuertoID") REFERENCES "PM_Puertos"("ID") ON DELETE RESTRICT
);

CREATE TABLE "PM_EstimadoGang" (
  "ID" INTEGER PRIMARY KEY AUTOINCREMENT,
  "EscalaID" INTEGER NOT NULL CHECK ("EscalaID" IS NULL OR (typeof("EscalaID")='integer' AND "EscalaID">=0)),
  "CodigoGang" TEXT NOT NULL,
  "CodigoGrua" TEXT,
  "MovimientosAsignados" INTEGER NOT NULL CHECK ("MovimientosAsignados" IS NULL OR (typeof("MovimientosAsignados")='integer' AND "MovimientosAsignados">=0)),
  "ProductividadMeta" REAL CHECK ("ProductividadMeta" IS NULL OR (typeof("ProductividadMeta") IN ('real','integer') AND "ProductividadMeta">=0)),
  "HorasPrevistas" REAL CHECK ("HorasPrevistas" IS NULL OR (typeof("HorasPrevistas") IN ('real','integer') AND "HorasPrevistas">=0)),
  "Notas" TEXT,
  FOREIGN KEY ("EscalaID") REFERENCES "PM_Escalas"("ID") ON DELETE RESTRICT
);

CREATE TABLE "PM_EstimadoGangDetalle" (
  "ID" INTEGER PRIMARY KEY AUTOINCREMENT,
  "GangID" INTEGER NOT NULL CHECK ("GangID" IS NULL OR (typeof("GangID")='integer' AND "GangID">=0)),
  "TipoMovimientoID" INTEGER NOT NULL CHECK ("TipoMovimientoID" IS NULL OR (typeof("TipoMovimientoID")='integer' AND "TipoMovimientoID">=0)),
  "Cantidad" INTEGER NOT NULL CHECK ("Cantidad" IS NULL OR (typeof("Cantidad")='integer' AND "Cantidad">=0)),
  FOREIGN KEY ("GangID") REFERENCES "PM_EstimadoGang"("ID") ON DELETE RESTRICT,
  FOREIGN KEY ("TipoMovimientoID") REFERENCES "PM_TiposMovimiento"("ID") ON DELETE RESTRICT
);

CREATE TABLE "PM_TiposMovimiento" (
  "ID" INTEGER PRIMARY KEY AUTOINCREMENT,
  "Codigo" TEXT NOT NULL,
  "Grupo" TEXT NOT NULL,
  "Nombre" TEXT NOT NULL,
  "CuentaEnTotal" INTEGER NOT NULL DEFAULT 0 CHECK ("CuentaEnTotal" IN (0,1)),
  "Activo" INTEGER NOT NULL DEFAULT 0 CHECK ("Activo" IN (0,1))
);

CREATE TABLE "PM_HourlyGang" (
  "ID" INTEGER PRIMARY KEY AUTOINCREMENT,
  "HourlyID" INTEGER NOT NULL CHECK ("HourlyID" IS NULL OR (typeof("HourlyID")='integer' AND "HourlyID">=0)),
  "GangID" INTEGER NOT NULL CHECK ("GangID" IS NULL OR (typeof("GangID")='integer' AND "GangID">=0)),
  "MovimientosHora" INTEGER NOT NULL CHECK ("MovimientosHora" IS NULL OR (typeof("MovimientosHora")='integer' AND "MovimientosHora">=0)),
  "RestantesAlCorte" INTEGER CHECK ("RestantesAlCorte" IS NULL OR (typeof("RestantesAlCorte")='integer' AND "RestantesAlCorte">=0)),
  FOREIGN KEY ("HourlyID") REFERENCES "PM_Hourly"("ID") ON DELETE RESTRICT,
  FOREIGN KEY ("GangID") REFERENCES "PM_EstimadoGang"("ID") ON DELETE RESTRICT,
  UNIQUE ("HourlyID","GangID")
);

CREATE TABLE "PM_Exclusiones" (
  "ID" INTEGER PRIMARY KEY AUTOINCREMENT,
  "EscalaID" INTEGER NOT NULL CHECK ("EscalaID" IS NULL OR (typeof("EscalaID")='integer' AND "EscalaID">=0)),
  "TipoMovimientoID" INTEGER NOT NULL CHECK ("TipoMovimientoID" IS NULL OR (typeof("TipoMovimientoID")='integer' AND "TipoMovimientoID">=0)),
  "Cantidad" INTEGER NOT NULL CHECK ("Cantidad" IS NULL OR (typeof("Cantidad")='integer' AND "Cantidad">=0)),
  "Motivo" TEXT NOT NULL,
  "RegistradaUTC" TEXT NOT NULL,
  "ActorID" INTEGER NOT NULL CHECK ("ActorID" IS NULL OR (typeof("ActorID")='integer' AND "ActorID">=0)),
  "Validado" INTEGER NOT NULL DEFAULT 0 CHECK ("Validado" IN (0,1)),
  "GangID" INTEGER CHECK ("GangID" IS NULL OR (typeof("GangID")='integer' AND "GangID">=0)),
  FOREIGN KEY ("EscalaID") REFERENCES "PM_Escalas"("ID") ON DELETE RESTRICT,
  FOREIGN KEY ("TipoMovimientoID") REFERENCES "PM_TiposMovimiento"("ID") ON DELETE RESTRICT,
  FOREIGN KEY ("ActorID") REFERENCES "PM_Usuarios"("ID") ON DELETE RESTRICT,
  FOREIGN KEY ("GangID") REFERENCES "PM_EstimadoGang"("ID") ON DELETE RESTRICT
);

CREATE TABLE "PM_CierreHourly" (
  "ID" INTEGER PRIMARY KEY AUTOINCREMENT,
  "EscalaID" INTEGER NOT NULL CHECK ("EscalaID" IS NULL OR (typeof("EscalaID")='integer' AND "EscalaID">=0)),
  "Finalizado" INTEGER NOT NULL DEFAULT 0 CHECK ("Finalizado" IN (0,1)),
  "FinalizadoUTC" TEXT,
  "FinalizadoPorID" INTEGER CHECK ("FinalizadoPorID" IS NULL OR (typeof("FinalizadoPorID")='integer' AND "FinalizadoPorID">=0)),
  "MovInicial" INTEGER CHECK ("MovInicial" IS NULL OR (typeof("MovInicial")='integer' AND "MovInicial">=0)),
  "MovReal" INTEGER CHECK ("MovReal" IS NULL OR (typeof("MovReal")='integer' AND "MovReal">=0)),
  "MovExcluido" INTEGER CHECK ("MovExcluido" IS NULL OR (typeof("MovExcluido")='integer' AND "MovExcluido">=0)),
  "SaldoFinal" INTEGER CHECK ("SaldoFinal" IS NULL OR (typeof("SaldoFinal")='integer' AND "SaldoFinal">=0)),
  "ProdRealFinal" REAL CHECK ("ProdRealFinal" IS NULL OR (typeof("ProdRealFinal") IN ('real','integer') AND "ProdRealFinal">=0)),
  "ProdEstimada" REAL CHECK ("ProdEstimada" IS NULL OR (typeof("ProdEstimada") IN ('real','integer') AND "ProdEstimada">=0)),
  FOREIGN KEY ("EscalaID") REFERENCES "PM_Escalas"("ID") ON DELETE RESTRICT,
  FOREIGN KEY ("FinalizadoPorID") REFERENCES "PM_Usuarios"("ID") ON DELETE RESTRICT,
  UNIQUE ("EscalaID")
);

CREATE TABLE "PM_TiposHito" (
  "ID" INTEGER PRIMARY KEY AUTOINCREMENT,
  "Codigo" TEXT NOT NULL,
  "ReporteTipo" TEXT NOT NULL,
  "Orden" INTEGER NOT NULL CHECK ("Orden" IS NULL OR (typeof("Orden")='integer' AND "Orden">=0)),
  "Descripcion" TEXT NOT NULL,
  "Obligatorio" INTEGER NOT NULL DEFAULT 0 CHECK ("Obligatorio" IN (0,1)),
  "PermiteNA" INTEGER NOT NULL DEFAULT 0 CHECK ("PermiteNA" IN (0,1))
);

CREATE TABLE "PM_HitosBuque" (
  "ID" INTEGER PRIMARY KEY AUTOINCREMENT,
  "EscalaID" INTEGER NOT NULL CHECK ("EscalaID" IS NULL OR (typeof("EscalaID")='integer' AND "EscalaID">=0)),
  "TipoHitoID" INTEGER NOT NULL CHECK ("TipoHitoID" IS NULL OR (typeof("TipoHitoID")='integer' AND "TipoHitoID">=0)),
  "FechaHoraUTC" TEXT,
  "NoAplica" INTEGER NOT NULL DEFAULT 0 CHECK ("NoAplica" IN (0,1)),
  "Justificacion" TEXT,
  "Validacion" TEXT NOT NULL,
  "ActualizadoPorID" INTEGER CHECK ("ActualizadoPorID" IS NULL OR (typeof("ActualizadoPorID")='integer' AND "ActualizadoPorID">=0)),
  FOREIGN KEY ("EscalaID") REFERENCES "PM_Escalas"("ID") ON DELETE RESTRICT,
  FOREIGN KEY ("TipoHitoID") REFERENCES "PM_TiposHito"("ID") ON DELETE RESTRICT,
  FOREIGN KEY ("ActualizadoPorID") REFERENCES "PM_Usuarios"("ID") ON DELETE RESTRICT,
  UNIQUE ("EscalaID","TipoHitoID")
);

CREATE TABLE "PM_ReportesMaritimos" (
  "ID" INTEGER PRIMARY KEY AUTOINCREMENT,
  "EscalaID" INTEGER NOT NULL CHECK ("EscalaID" IS NULL OR (typeof("EscalaID")='integer' AND "EscalaID">=0)),
  "TipoReporte" TEXT NOT NULL,
  "RemolcadoresQty" INTEGER CHECK ("RemolcadoresQty" IS NULL OR (typeof("RemolcadoresQty")='integer' AND "RemolcadoresQty">=0)),
  "RemolcadoresNombre" TEXT,
  "RemolqueDesdeUTC" TEXT,
  "RemolqueHastaUTC" TEXT,
  "FuelOilMT" REAL CHECK ("FuelOilMT" IS NULL OR (typeof("FuelOilMT") IN ('real','integer') AND "FuelOilMT">=0)),
  "DieselOilMT" REAL CHECK ("DieselOilMT" IS NULL OR (typeof("DieselOilMT") IN ('real','integer') AND "DieselOilMT">=0)),
  "FreshWaterMT" REAL CHECK ("FreshWaterMT" IS NULL OR (typeof("FreshWaterMT") IN ('real','integer') AND "FreshWaterMT">=0)),
  "DraftFwdM" REAL CHECK ("DraftFwdM" IS NULL OR (typeof("DraftFwdM") IN ('real','integer') AND "DraftFwdM">=0)),
  "DraftAftM" REAL CHECK ("DraftAftM" IS NULL OR (typeof("DraftAftM") IN ('real','integer') AND "DraftAftM">=0)),
  "PuertoAnteriorID" INTEGER CHECK ("PuertoAnteriorID" IS NULL OR (typeof("PuertoAnteriorID")='integer' AND "PuertoAnteriorID">=0)),
  "PuertoSiguienteID" INTEGER CHECK ("PuertoSiguienteID" IS NULL OR (typeof("PuertoSiguienteID")='integer' AND "PuertoSiguienteID">=0)),
  "ETASiguienteUTC" TEXT,
  "Observaciones" TEXT,
  "EstadoReporte" TEXT NOT NULL,
  "ValidadorID" INTEGER CHECK ("ValidadorID" IS NULL OR (typeof("ValidadorID")='integer' AND "ValidadorID">=0)),
  "ValidadoUTC" TEXT,
  FOREIGN KEY ("EscalaID") REFERENCES "PM_Escalas"("ID") ON DELETE RESTRICT,
  FOREIGN KEY ("PuertoAnteriorID") REFERENCES "PM_Puertos"("ID") ON DELETE RESTRICT,
  FOREIGN KEY ("PuertoSiguienteID") REFERENCES "PM_Puertos"("ID") ON DELETE RESTRICT,
  FOREIGN KEY ("ValidadorID") REFERENCES "PM_Usuarios"("ID") ON DELETE RESTRICT,
  UNIQUE ("EscalaID","TipoReporte")
);

CREATE TABLE "PM_IncidenciasValidacion" (
  "ID" INTEGER PRIMARY KEY AUTOINCREMENT,
  "EscalaID" INTEGER NOT NULL CHECK ("EscalaID" IS NULL OR (typeof("EscalaID")='integer' AND "EscalaID">=0)),
  "CodigoRegla" TEXT NOT NULL,
  "Nivel" TEXT NOT NULL,
  "Entidad" TEXT NOT NULL,
  "RegistroID" INTEGER CHECK ("RegistroID" IS NULL OR (typeof("RegistroID")='integer' AND "RegistroID">=0)),
  "Mensaje" TEXT NOT NULL,
  "Justificacion" TEXT,
  "Revisada" INTEGER NOT NULL DEFAULT 0 CHECK ("Revisada" IN (0,1)),
  "RevisadoPorID" INTEGER CHECK ("RevisadoPorID" IS NULL OR (typeof("RevisadoPorID")='integer' AND "RevisadoPorID">=0)),
  "FechaUTC" TEXT NOT NULL,
  FOREIGN KEY ("EscalaID") REFERENCES "PM_Escalas"("ID") ON DELETE RESTRICT,
  FOREIGN KEY ("RevisadoPorID") REFERENCES "PM_Usuarios"("ID") ON DELETE RESTRICT
);

CREATE TABLE "PM_CatalogoParametros" (
  "ID" INTEGER PRIMARY KEY AUTOINCREMENT,
  "Codigo" TEXT NOT NULL,
  "ServicioID" INTEGER CHECK ("ServicioID" IS NULL OR (typeof("ServicioID")='integer' AND "ServicioID">=0)),
  "TipoValor" TEXT NOT NULL,
  "ValorNumero" REAL CHECK ("ValorNumero" IS NULL OR (typeof("ValorNumero") IN ('real','integer') AND "ValorNumero">=0)),
  "ValorTexto" TEXT,
  "Unidad" TEXT,
  "Activo" INTEGER NOT NULL DEFAULT 0 CHECK ("Activo" IN (0,1)),
  FOREIGN KEY ("ServicioID") REFERENCES "PM_Servicios"("ID") ON DELETE RESTRICT
);

CREATE INDEX "IX_PM_Usuarios_RolID" ON "PM_Usuarios"("RolID");

CREATE INDEX "IX_PM_Credenciales_UsuarioID" ON "PM_Credenciales"("UsuarioID");

CREATE INDEX "IX_PM_Equipos_UsuarioID" ON "PM_Equipos"("UsuarioID");

CREATE INDEX "IX_PM_Equipos_VerificadoPorID" ON "PM_Equipos"("VerificadoPorID");

CREATE INDEX "IX_PM_Escalas_BuqueID" ON "PM_Escalas"("BuqueID");

CREATE INDEX "IX_PM_Escalas_CerradoPorID" ON "PM_Escalas"("CerradoPorID");

CREATE INDEX "IX_PM_ETA_Historial_EscalaID" ON "PM_ETA_Historial"("EscalaID");

CREATE INDEX "IX_PM_ETA_Historial_ActorID" ON "PM_ETA_Historial"("ActorID");

CREATE INDEX "IX_PM_Asignaciones_EscalaID" ON "PM_Asignaciones"("EscalaID");

CREATE INDEX "IX_PM_Asignaciones_UsuarioID" ON "PM_Asignaciones"("UsuarioID");

CREATE INDEX "IX_PM_Asignaciones_AsignadoPorID" ON "PM_Asignaciones"("AsignadoPorID");

CREATE INDEX "IX_PM_ControlEdicion_EscalaID" ON "PM_ControlEdicion"("EscalaID");

CREATE INDEX "IX_PM_ControlEdicion_TitularUsuarioID" ON "PM_ControlEdicion"("TitularUsuarioID");

CREATE INDEX "IX_PM_ControlEdicion_SesionTrabajoID" ON "PM_ControlEdicion"("SesionTrabajoID");

CREATE INDEX "IX_PM_SesionesTrabajo_EscalaID" ON "PM_SesionesTrabajo"("EscalaID");

CREATE INDEX "IX_PM_SesionesTrabajo_UsuarioID" ON "PM_SesionesTrabajo"("UsuarioID");

CREATE INDEX "IX_PM_SesionesTrabajo_EquipoID" ON "PM_SesionesTrabajo"("EquipoID");

CREATE INDEX "IX_PM_TareasProyecto_EscalaID" ON "PM_TareasProyecto"("EscalaID");

CREATE INDEX "IX_PM_TareasProyecto_CatalogoTareaID" ON "PM_TareasProyecto"("CatalogoTareaID");

CREATE INDEX "IX_PM_TareasProyecto_CreadaPorID" ON "PM_TareasProyecto"("CreadaPorID");

CREATE INDEX "IX_PM_TareasProyecto_RealizadaPorID" ON "PM_TareasProyecto"("RealizadaPorID");

CREATE INDEX "IX_PM_Estimados_EscalaID" ON "PM_Estimados"("EscalaID");

CREATE INDEX "IX_PM_VaciosDestino_EscalaID" ON "PM_VaciosDestino"("EscalaID");

CREATE INDEX "IX_PM_Hourly_EscalaID" ON "PM_Hourly"("EscalaID");

CREATE INDEX "IX_PM_Hourly_ActualizadoPorID" ON "PM_Hourly"("ActualizadoPorID");

CREATE INDEX "IX_PM_Eventos_EscalaID" ON "PM_Eventos"("EscalaID");

CREATE INDEX "IX_PM_Eventos_ActorID" ON "PM_Eventos"("ActorID");

CREATE INDEX "IX_PM_Eventos_EquipoID" ON "PM_Eventos"("EquipoID");

CREATE INDEX "IX_PM_Eventos_SesionTrabajoID" ON "PM_Eventos"("SesionTrabajoID");

CREATE INDEX "IX_PM_Relevos_EscalaID" ON "PM_Relevos"("EscalaID");

CREATE INDEX "IX_PM_Relevos_SaleUsuarioID" ON "PM_Relevos"("SaleUsuarioID");

CREATE INDEX "IX_PM_Relevos_EntraUsuarioID" ON "PM_Relevos"("EntraUsuarioID");

CREATE INDEX "IX_PM_Revisiones_EscalaID" ON "PM_Revisiones"("EscalaID");

CREATE INDEX "IX_PM_Revisiones_GerenteID" ON "PM_Revisiones"("GerenteID");

CREATE INDEX "IX_PM_Evaluaciones_EscalaID" ON "PM_Evaluaciones"("EscalaID");

CREATE INDEX "IX_PM_Evaluaciones_AuditorID" ON "PM_Evaluaciones"("AuditorID");

CREATE INDEX "IX_PM_Evaluaciones_CriterioID" ON "PM_Evaluaciones"("CriterioID");

CREATE INDEX "IX_PM_Evaluaciones_GerenteID" ON "PM_Evaluaciones"("GerenteID");

CREATE INDEX "IX_PM_PermisosRol_RolID" ON "PM_PermisosRol"("RolID");

CREATE INDEX "IX_PM_PermisosRol_ModificadoPorID" ON "PM_PermisosRol"("ModificadoPorID");

CREATE INDEX "IX_PM_Escalas_ServicioID" ON "PM_Escalas"("ServicioID");

CREATE INDEX "IX_PM_Escalas_AgenteID" ON "PM_Escalas"("AgenteID");

CREATE INDEX "IX_PM_VaciosDestino_PuertoID" ON "PM_VaciosDestino"("PuertoID");

CREATE INDEX "IX_PM_EstimadoGang_EscalaID" ON "PM_EstimadoGang"("EscalaID");

CREATE INDEX "IX_PM_EstimadoGangDetalle_GangID" ON "PM_EstimadoGangDetalle"("GangID");

CREATE INDEX "IX_PM_EstimadoGangDetalle_TipoMovimientoID" ON "PM_EstimadoGangDetalle"("TipoMovimientoID");

CREATE INDEX "IX_PM_HourlyGang_HourlyID" ON "PM_HourlyGang"("HourlyID");

CREATE INDEX "IX_PM_HourlyGang_GangID" ON "PM_HourlyGang"("GangID");

CREATE INDEX "IX_PM_Exclusiones_EscalaID" ON "PM_Exclusiones"("EscalaID");

CREATE INDEX "IX_PM_Exclusiones_TipoMovimientoID" ON "PM_Exclusiones"("TipoMovimientoID");

CREATE INDEX "IX_PM_Exclusiones_ActorID" ON "PM_Exclusiones"("ActorID");

CREATE INDEX "IX_PM_CierreHourly_EscalaID" ON "PM_CierreHourly"("EscalaID");

CREATE INDEX "IX_PM_CierreHourly_FinalizadoPorID" ON "PM_CierreHourly"("FinalizadoPorID");

CREATE INDEX "IX_PM_HitosBuque_EscalaID" ON "PM_HitosBuque"("EscalaID");

CREATE INDEX "IX_PM_HitosBuque_TipoHitoID" ON "PM_HitosBuque"("TipoHitoID");

CREATE INDEX "IX_PM_HitosBuque_ActualizadoPorID" ON "PM_HitosBuque"("ActualizadoPorID");

CREATE INDEX "IX_PM_ReportesMaritimos_EscalaID" ON "PM_ReportesMaritimos"("EscalaID");

CREATE INDEX "IX_PM_ReportesMaritimos_PuertoAnteriorID" ON "PM_ReportesMaritimos"("PuertoAnteriorID");

CREATE INDEX "IX_PM_ReportesMaritimos_PuertoSiguienteID" ON "PM_ReportesMaritimos"("PuertoSiguienteID");

CREATE INDEX "IX_PM_ReportesMaritimos_ValidadorID" ON "PM_ReportesMaritimos"("ValidadorID");

CREATE INDEX "IX_PM_IncidenciasValidacion_EscalaID" ON "PM_IncidenciasValidacion"("EscalaID");

CREATE INDEX "IX_PM_IncidenciasValidacion_RevisadoPorID" ON "PM_IncidenciasValidacion"("RevisadoPorID");

CREATE INDEX "IX_PM_CatalogoParametros_ServicioID" ON "PM_CatalogoParametros"("ServicioID");

CREATE INDEX "IX_PM_RutasServicio_ServicioID" ON "PM_RutasServicio"("ServicioID");

CREATE INDEX "IX_PM_RutasServicio_PuertoID" ON "PM_RutasServicio"("PuertoID");

CREATE INDEX "IX_PM_Exclusiones_GangID" ON "PM_Exclusiones"("GangID");

CREATE INDEX "IX_PM_Escalas_EstadoProyecto" ON "PM_Escalas"("EstadoProyecto");

CREATE INDEX "IX_PM_Escalas_FechaETA" ON "PM_Escalas"("FechaETA");

CREATE INDEX "IX_PM_Eventos_FechaUTC" ON "PM_Eventos"("FechaUTC");

CREATE TABLE local_settings (key TEXT PRIMARY KEY, value TEXT NOT NULL);
