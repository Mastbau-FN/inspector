--
-- PostgreSQL database dump
--

-- Dumped from database version 10.14 (Ubuntu 10.14-1.pgdg16.04+1)
-- Dumped by pg_dump version 10.14 (Ubuntu 10.14-1.pgdg16.04+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: citext; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;


--
-- Name: EXTENSION citext; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION citext IS 'data type for case-insensitive character strings';


--
-- Name: events_index_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.events_index_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.events_index_seq OWNER TO postgres;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: Events; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Events" (
    "Index" integer DEFAULT nextval('public.events_index_seq'::regclass) NOT NULL,
    "IndexDat" date DEFAULT ('now'::text)::date,
    "EventID" integer DEFAULT 0,
    "Datum" date DEFAULT ('now'::text)::date,
    "Zeit" timestamp(0) without time zone DEFAULT (('30-12-1899 '::text || LOCALTIME))::timestamp(0) without time zone,
    "BisDatum" date DEFAULT ('now'::text)::date,
    "BisZeit" timestamp(0) without time zone DEFAULT (('30-12-1899 '::text || LOCALTIME))::timestamp(0) without time zone,
    "Dauer" double precision DEFAULT 0,
    "GanzTag" boolean DEFAULT false,
    "Autor" public.citext,
    "PsNr" integer DEFAULT 0,
    "AusEin" integer DEFAULT 0,
    "AnVon" integer DEFAULT 1,
    "IDNr" integer DEFAULT 0,
    "PjNr" integer DEFAULT 0,
    "Art" integer DEFAULT 0,
    "KurzText" public.citext,
    "LangText" text,
    "Link" character varying(255),
    "LinkOrdner" character varying(255),
    "LinkQuelle" character varying(255),
    "istImportiert" boolean DEFAULT false,
    "ErDat" date,
    "ErZei" timestamp(0) without time zone,
    "EREArt" integer DEFAULT 0,
    "Update_Date" timestamp(0) without time zone DEFAULT ('now'::text)::timestamp(0) without time zone,
    "Prio" integer DEFAULT '-9'::integer,
    "nextStep" boolean DEFAULT false,
    "IndexReply" integer DEFAULT 0,
    "KGZ_Ext_ID" integer DEFAULT 0,
    "E1" integer,
    "E2" integer,
    "E3" integer,
    "Insp_Stelle" character varying(255)
);


ALTER TABLE public."Events" OWNER TO postgres;

--
-- Name: MGAUFTR; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."MGAUFTR" (
    "PjNr" integer DEFAULT 0 NOT NULL,
    "PjNr_HP" integer,
    "PjTypID" integer DEFAULT 99,
    "Status" public.citext DEFAULT 'oRA'::character varying,
    "Status_HP" character varying(6),
    "AnzahlAuHProjekte" double precision,
    "MBG" smallint DEFAULT 0,
    "HP_RANr" double precision,
    "Verfolgung" boolean DEFAULT true,
    "StONr" integer DEFAULT 0,
    "VhNr" double precision DEFAULT 0,
    "SGNr" integer DEFAULT 0,
    "PreisCode" integer DEFAULT 0,
    "AuDatum" date,
    "AuForm" character varying(10) DEFAULT 'mündl.'::character varying,
    "ANG_Dat" date,
    "ANG_Sum" double precision DEFAULT 0,
    "ANG_Frei" date,
    "Netzbetreiber" smallint DEFAULT 0,
    "InKuNr" double precision DEFAULT 0,
    "InKuNrIndex" integer DEFAULT 1,
    "EndKuNr" integer DEFAULT 0,
    "EndKuNrIndex" integer DEFAULT 1,
    "RAanKuNr" double precision DEFAULT 0,
    "RAanAnIndex" integer DEFAULT 1,
    "VM_Orga_ID" integer DEFAULT 0,
    "VM_ASP_ID" integer DEFAULT 1,
    "RV_ID" integer DEFAULT 0,
    "RV_Rabatt" double precision DEFAULT 0,
    "NeNr" double precision DEFAULT 0,
    "PjGrNr" double precision DEFAULT 1000,
    "PjName" public.citext,
    "PjInfo" public.citext,
    "VLeitung" public.citext,
    "PjLeitung" public.citext,
    "Bauleitung" public.citext,
    "BauteitungEXTERN" character varying(3),
    "AuftrNrEXTERN1" character varying(75),
    "AuftrNrEXTERN2" character varying(75),
    "AuftrNrEXTERN3" character varying(75),
    "AuftrNrEXTERN4" character varying(75),
    "AuftrNrEXTERN5" character varying(75),
    "AuftrDatEXTERN" date,
    "AuftrBestSAP" date,
    "LIEanEXT" integer DEFAULT 9,
    "LIEanEXTIndex" integer DEFAULT 1,
    "LIEanEXT_Info" character varying(150),
    "LTDatEXT" date,
    "Bem_INT" text,
    "Bem_EXT" character varying(150),
    "Baufrei" character varying(5),
    "MannStd" double precision DEFAULT 0,
    "DiffStd" double precision DEFAULT 0,
    "Max_Event_Dat" timestamp(0) without time zone,
    "Max_Event_Zeit" timestamp(0) without time zone DEFAULT (('30-12-1899 '::text || LOCALTIME))::timestamp(0) without time zone,
    "Max_Event_KurzText" character varying(150),
    "Max_Mont_Dat" date,
    "Buget" double precision DEFAULT 0,
    "Buget_Dat" date,
    "UmsProg" double precision DEFAULT 0,
    "UmsProg_Art" character varying(3),
    "UmsProg_Dat" date,
    "Sum_STD" double precision DEFAULT 0,
    "Sum_STD_MP" double precision DEFAULT 0,
    "Sum_STD_KGZ_0" double precision DEFAULT 0,
    "Sum_STD_KGZ_1" double precision DEFAULT 0,
    "Sum_STD_KGZ_2" double precision DEFAULT 0,
    "Sum_STD_KGZ_3" double precision DEFAULT 0,
    "Sum_STD_KGZ_4" double precision DEFAULT 0,
    "Sum_STD_KGZ_5" double precision DEFAULT 0,
    "Sum_STD_KGZ_6" double precision DEFAULT 0,
    "Sum_STD_KGZ_8" double precision DEFAULT 0,
    "Sum_STD_ALP" double precision DEFAULT 0,
    "Sum_MAT" double precision DEFAULT 0,
    "Sum_RE" double precision DEFAULT 0,
    "Sum_RE_oA" double precision DEFAULT 0,
    "Sum_KAS" double precision DEFAULT 0,
    "Sum_RA" double precision DEFAULT 0,
    "Zahlungen_Pos_Sum" double precision DEFAULT 0,
    "Zahlungen_Neg_Sum" double precision DEFAULT 0,
    "Zahlungen_Anzahl" integer DEFAULT 0,
    "DB" double precision,
    "Check_STD" timestamp(0) without time zone,
    "Check_MAT" timestamp(0) without time zone,
    "Check_RE" timestamp(0) without time zone,
    "Check_RA" date,
    "Plan_Start" date,
    "Plan_Ende" date,
    "Start" date,
    "Ende" date,
    "Bearbeitungszeit" double precision DEFAULT 0,
    "ÄndFLT" date,
    "FLT" date,
    "ÄndBZA" date,
    "BZA" date,
    "MatDat" timestamp(0) without time zone,
    "Aktiv" boolean DEFAULT false,
    "Fertig" boolean DEFAULT false,
    "BauInfo" character varying(255),
    "BereitZurAbnahme" boolean DEFAULT false,
    "AbnahmeDat" date,
    "AbnahmeMangelOffen" date,
    "RestleistungOffen" date,
    "InspektMangelOffen" timestamp(0) without time zone,
    "BereitZurSR" boolean DEFAULT false,
    "SR_Dat" date,
    "Prio_ID_Bau" integer DEFAULT 2,
    "Länder_ID" integer DEFAULT 1,
    "Std_Satz_Sonst" double precision,
    "Std_Satz_VW" double precision,
    "Std_Satz_BL" double precision,
    "Std_Satz_Mont" double precision,
    "Std_Satz_MontFremd" double precision,
    "Std_Satz_AKQ" double precision,
    "Std_Satz_CAD" double precision,
    "Std_Satz_Statik" double precision,
    "GKZ_Mat" double precision,
    "GKZ_Fremd" double precision,
    "GKZ_Kasse" double precision,
    "LB_ID" integer DEFAULT '-9'::integer,
    "initMP_PsNr" integer DEFAULT 0,
    "initMP_Dat" date,
    "Montage_Info" character varying(150),
    "Montage_Info_KZL" character varying(10),
    "Montage_Prio" smallint DEFAULT 0,
    "Montage_Tage" integer,
    "Montage_Mont" smallint,
    "Montage_Fremd" boolean DEFAULT false,
    "istMBGPaar" boolean DEFAULT false,
    "Material_Engpass" integer DEFAULT 1,
    "Montage_Start_Wunsch" date,
    "Montage_Ende" timestamp(0) without time zone,
    "Montage_Forecast" boolean DEFAULT false,
    "Montage_Sa_inkl" boolean DEFAULT true,
    "KGZ_Ext_ID" integer DEFAULT 0
);


ALTER TABLE public."MGAUFTR" OWNER TO postgres;

--
-- Name: STANDORT; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."STANDORT" (
    "StONr" integer DEFAULT 0 NOT NULL,
    "CreatedByPsNr" integer DEFAULT 0,
    "StOaktiv" boolean DEFAULT true,
    "TECH_Typ_ID" smallint DEFAULT 0,
    "StO_Typ_ID" smallint DEFAULT 0,
    "ESS_KAN" boolean DEFAULT false,
    "InspektionErforderlich" boolean DEFAULT false,
    "StONrBH" character varying(20),
    "BYNr" character varying(8),
    "BHNr" integer DEFAULT 1,
    "StO_Suchgebiet" character varying(100),
    "Straße" public.citext,
    "PLZ" character varying(5),
    "Ort" public.citext DEFAULT 'Berlin'::character varying,
    "Ortsteil" public.citext,
    "Bezirk" character varying(50),
    "Region" character varying(10),
    "Bundesland_ID" smallint DEFAULT 0,
    "RegionZiffer" integer DEFAULT 0,
    "StO_Inh_Info" character varying(200),
    "StO_ET" integer DEFAULT 9,
    "StO_HV" integer DEFAULT 9,
    "Beschreibung Telekom" character varying(50),
    "Beschreibung2" character varying(50),
    "AufbauFIRMA" character varying(10) DEFAULT 'MBG'::character varying,
    "Beschreibung MBG" public.citext,
    "InfoMBG" public.citext,
    "GEO_STR" character varying(150),
    "GEO_HNr" character varying(3),
    "GEO_HNrZ" character varying(2),
    "GEO_Hoehe" double precision,
    "IMM_Höhe" double precision,
    "IMM_Hoehe_Qual_ID" integer DEFAULT 0,
    "IMM_Typ" character varying(50),
    "IMM_Ges" integer,
    "IMM_Dach" character varying(50),
    "PV_Dachneigung" double precision,
    "PV_AzimuthSüd" double precision DEFAULT '-99'::integer,
    "StO_Status" character varying(30),
    "StO_Nutz_TMO" date,
    "StO_Nutz_MMO" date,
    "StO_Nutz_MCMM" timestamp(0) without time zone,
    "StO_Nutz_O2" date,
    "StO_Nutz_EPLUS" date,
    "StO_Nutz_SIG" date,
    "StO_MN_MMO" boolean DEFAULT false,
    "StO_MN_Eplus" boolean DEFAULT false,
    "StO_MN_VIAG" boolean DEFAULT false,
    "StO_MN_Sonst" character varying(50),
    "StO_MN_Info" character varying(200),
    "StO_MN_Info_Dat" date,
    "DIENST_D1_900" boolean DEFAULT false,
    "DIENST_D1_1800" boolean DEFAULT false,
    "DIENST_D1_UMTS" boolean DEFAULT false,
    "DIENST_C-Netz" boolean DEFAULT false,
    "DIENST_Modacom" boolean DEFAULT false,
    "DIENST_Sonst" character varying(150),
    "DIENST_Info" character varying(150),
    "ATR_Anz" integer DEFAULT 0,
    "ATR_KLmax" double precision DEFAULT 0,
    "ATR_NLmax" double precision DEFAULT 0,
    "ATR_KL>10m" boolean DEFAULT false,
    "ATR_HüTmax" double precision DEFAULT 0,
    "ATR_EWT_Info" character varying(200),
    "ANT_Konzept_ID" smallint DEFAULT 0,
    "ANT_GFK" boolean DEFAULT false,
    "ANT_VF" boolean DEFAULT false,
    "ANT_HF" boolean DEFAULT false,
    "FertigDat" date,
    "UmbauDat" date,
    "Bearbeiter" double precision DEFAULT 0,
    "TuBuErforderlich" boolean DEFAULT true,
    "InfoDatErforderlich" date,
    "TuBuRAUSmaxDat" date,
    "InfoTuBu" character varying(50),
    "StO_fertig" boolean DEFAULT false,
    "InfoDatFertig" date,
    "StatikenATRda" boolean DEFAULT false,
    "InfoDatATR" date,
    "StatikenGEBda" boolean DEFAULT false,
    "InfoDatGEB" date,
    "FotosDa" boolean DEFAULT false,
    "InfoDatFoto" date,
    "WegDa" boolean DEFAULT false,
    "InfoDatWeg" date,
    "TuBuNEXTart" character varying(10) DEFAULT 'NEU'::character varying,
    "SchildErf" boolean DEFAULT false,
    "SchildBest-Alt" date,
    "SchildBest" date,
    "SchildMont" date,
    "01" boolean DEFAULT true,
    "02" boolean DEFAULT true,
    "03" boolean DEFAULT true,
    "04" boolean DEFAULT true,
    "05" boolean DEFAULT true,
    "06" boolean DEFAULT true,
    "07" boolean DEFAULT true,
    "08" boolean DEFAULT true,
    "Insp1996" date,
    "Insp1997" date,
    "Insp1998" date,
    "Insp1999" date,
    "Insp2000" timestamp(0) without time zone,
    "StONr_DFMG" public.citext,
    "StONr_TMobile" public.citext,
    "StONr_Vodafone" public.citext,
    "StONr_EPlus" public.citext,
    "StONr_O2" public.citext,
    "StOName_Sonstige1" public.citext,
    "StOName_Sonstige2" public.citext,
    "StOName_DFMG" public.citext,
    "StOName_TMobile" public.citext,
    "StOName_Vodafone" public.citext,
    "StOName_EPlus" public.citext,
    "StOName_O2" public.citext,
    "StOSuchgebiet_DFMG" public.citext,
    "StOSuchgebiet_TMobile" public.citext,
    "StOSuchgebiet_Vodafone" public.citext,
    "StOSuchgebiet_EPlus" public.citext,
    "StOSuchgebiet_O2" public.citext,
    "SGNr_DFMG" integer DEFAULT 0,
    "SGNr_TMobile" integer DEFAULT 0,
    "SGNr_Vodafone" integer DEFAULT 0,
    "SGNr_EPlus" integer DEFAULT 0,
    "SGNr_O2" integer DEFAULT 0,
    "BSNr_EPlus_Master" public.citext,
    "BSNr_EPlus_UMTS" public.citext,
    "BSNr_EPlus_GMS" public.citext,
    "BSNr_EPlus_Erw1" public.citext,
    "BSNr_EPlus_Erw2" public.citext,
    "BSNr_O2_Master" public.citext,
    "BSNr_O2_UMTS" public.citext,
    "BSNr_O2_GMS" public.citext,
    "BSNr_O2_Erw1" public.citext,
    "BSNr_O2_Erw2" public.citext,
    "StO_Status_Suche" smallint DEFAULT 0,
    "StO_Status_Kandidat" smallint DEFAULT 0,
    "StO_Status_ESS" smallint DEFAULT 0,
    "StO_Status_Planung" smallint DEFAULT 0,
    "StO_Status_Bau" smallint DEFAULT 0,
    "StO_Status_Demontiert" smallint DEFAULT 0,
    "StO_Status_Fremd" smallint DEFAULT 0,
    "StONr_BDBOS" public.citext,
    "StONr_BDBOS_Brb" public.citext,
    "StOName_BDBOS" public.citext,
    "SGNr_BDBOS" public.citext,
    "NENr_BDBOS_1" public.citext,
    "NENr_BDBOS_2" public.citext,
    "NENr_BDBOS_3" public.citext,
    "NENr_BDBOS_4" public.citext,
    "SGNr_PV" integer DEFAULT 0,
    "StOSuchgebiet_PV" public.citext,
    "SGNr_Taxi" integer DEFAULT 0,
    "StOSuchgebiet_Taxi" public.citext,
    "SGNr_Sigfox" integer DEFAULT 0,
    "StOSuchgebiet_Sigfox" public.citext,
    "StONr_PV" public.citext,
    "Länder_ID" integer DEFAULT 1,
    "AdminRegion2_ID" integer DEFAULT 0,
    "Gemarkung" public.citext,
    "Flur" integer,
    "Flurstück" public.citext,
    "istPVStO" boolean DEFAULT false,
    "FLH" boolean DEFAULT false,
    "DMS" boolean DEFAULT false,
    "Windlast" character varying(50),
    "Schneelast" character varying(50),
    "NetzOrga_ID" integer DEFAULT 0,
    "Netzimpedanz" double precision,
    "Netzeinspeisung" double precision,
    "Netz_Einschr" text,
    "Netzklasse" smallint DEFAULT 0,
    "Notstromaggregat" double precision DEFAULT '-9'::integer,
    "Notstrom_typ" character varying(50),
    "ET_Typ_ID" integer DEFAULT 1,
    "DSL" smallint DEFAULT '-9'::integer,
    "StromAnschluss" smallint DEFAULT '-9'::integer,
    "EntfernungZuMBG" double precision
);


ALTER TABLE public."STANDORT" OWNER TO postgres;

--
-- Data for Name: Events; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."Events" ("Index", "IndexDat", "EventID", "Datum", "Zeit", "BisDatum", "BisZeit", "Dauer", "GanzTag", "Autor", "PsNr", "AusEin", "AnVon", "IDNr", "PjNr", "Art", "KurzText", "LangText", "Link", "LinkOrdner", "LinkQuelle", "istImportiert", "ErDat", "ErZei", "EREArt", "Update_Date", "Prio", "nextStep", "IndexReply", "KGZ_Ext_ID", "E1", "E2", "E3", "Insp_Stelle") FROM stdin;
944833	2021-07-21	0	2021-07-20	1899-12-30 12:38:00	2021-07-20	1899-12-30 12:38:00	0	f	Bn	161	0	1	0	6006259	0	Inspektionsprotokoll 2020	\N	\N	\N	\N	f	2021-07-21	1899-12-30 13:14:00	0	2021-07-21 13:14:17	-9	f	0	0	\N	\N	\N	\N
944820	2021-07-21	0	2021-07-21	1899-12-30 12:29:00	2021-07-21	1899-12-30 12:29:00	0	f	Bn	30	0	1	0	6006259	0	Endsperre	\N	\N	\N	\N	f	\N	\N	0	2021-07-21 13:14:48	-9	f	0	0	1	1	\N	\N
944827	2021-07-21	0	2021-07-21	1899-12-30 12:30:00	2021-07-21	1899-12-30 12:30:00	0	f	Bn	30	0	1	0	6006259	0	Steigweg	\N	\N	\N	\N	f	\N	\N	0	2021-07-21 13:14:50	-9	f	0	0	3	0	\N	\N
944832	2021-07-21	0	2021-07-20	1899-12-30 13:14:00	2021-07-20	1899-12-30 13:14:00	0	f	Bn	30	0	1	0	6006259	0	Übersichtsfoto	\N	\N	\N	\N	f	\N	\N	0	2021-07-21 13:15:30	-9	f	0	0	\N	\N	\N	\N
944834	2021-07-21	0	2021-07-20	1899-12-30 13:11:00	2021-07-20	1899-12-30 13:11:00	0	f	Bn	161	0	1	0	6006259	0	Monteur Inspektion: N.Lück	\N	\N	\N	\N	f	\N	\N	0	2021-07-21 13:15:34	-9	f	0	0	\N	\N	\N	\N
944821	2021-07-21	0	2021-07-21	1899-12-30 12:29:00	2021-07-21	1899-12-30 12:29:00	0	f	Bn	30	-1	1	0	6006259	0	Spaltmaße	\N	\N	\N	\N	f	2021-07-21	1899-12-30 13:18:00	0	2021-07-21 13:19:48	-9	f	0	0	1	2	\N	\N
944831	2021-07-21	0	2021-07-21	1899-12-30 12:31:00	2021-07-21	1899-12-30 12:38:00	0	f	Bn	30	0	1	0	6006259	0	Kennzeichnungsschild	\N	\N	\N	\N	f	\N	\N	0	2021-07-21 13:20:17	-9	f	0	0	3	3	\N	\N
944823	2021-07-21	6090	2021-07-21	1899-12-30 12:29:00	2021-07-21	1899-12-30 12:30:00	0	f	Bn	30	-1	1	0	6006259	0	Kabelweg	\N	\N	\N	\N	f	2021-07-21	1899-12-30 13:18:00	0	2021-08-12 12:41:39	-9	f	0	0	2	0	\N	\N
944824	2021-07-21	6094	2021-07-21	1899-12-30 12:30:00	2021-07-21	1899-12-30 12:30:00	0	f	Bn	30	0	1	0	6006259	0	Endsperre	\N	\N	\N	\N	f	\N	\N	0	2021-07-21 13:14:51	-9	f	0	0	2	1	\N	\N
944825	2021-07-21	6095	2021-07-21	1899-12-30 12:30:00	2021-07-21	1899-12-30 12:30:00	0	f	Bn	30	0	1	0	6006259	0	Spaltmaße	\N	\N	\N	\N	f	\N	\N	0	2021-07-21 13:14:53	-9	f	0	0	2	2	0	\N
944830	2021-07-21	0	2021-07-21	1899-12-30 12:31:00	2021-07-21	1899-12-30 12:31:00	0	f	Bn	30	1	1	0	6006259	0	Spaltmaße	Spaltmaß > 5mm	O:\\PDF_Prj\\0600-6200_0600-6299\\0600-6259 Inspektion 2021 Wilhelm-Kabus-Straße 21-35\\0600-6259_2021-07-21_Kennzeichnungsschild_Spaltmaße01.JPG	\N	\N	f	2021-07-21	1899-12-30 13:18:00	0	2021-07-21 14:26:05	-9	f	0	0	3	2	\N	\N
944819	2021-07-21	0	2021-07-21	1899-12-30 12:28:00	2021-07-21	1899-12-30 12:29:00	0	f	Bn	30	0	1	0	6006259	0	Mast	\N	\N	\N	\N	f	2021-07-21	1899-12-30 13:18:00	0	2021-07-21 14:06:29	-9	f	0	0	1	0	\N	\N
944822	2021-07-21	0	2021-07-21	1899-12-30 12:29:00	2021-07-21	1899-12-30 12:29:00	0	f	Bn	30	-1	1	0	6006259	0	Kennzeichnungsschild	\N	\N	\N	\N	f	2021-07-21	1899-12-30 13:18:00	0	2021-07-21 13:19:41	-9	f	0	0	1	3	\N	\N
944826	2021-07-21	6096	2021-07-21	1899-12-30 12:30:00	2021-07-21	1899-12-30 12:30:00	0	f	Bn	30	0	1	0	6006259	0	Kennzeichnungsschild	\N	\N	\N	\N	f	2021-07-21	1899-12-30 14:06:00	0	2021-07-21 14:24:19	-9	f	0	0	2	3	\N	\N
944829	2021-07-21	0	2021-07-21	1899-12-30 12:31:00	2021-07-21	1899-12-30 12:31:00	0	f	Bn	30	-1	1	0	6006259	0	Endsperre	Keine Mängel feststellbar	O:\\PDF_Prj\\0600-6200_0600-6299\\0600-6259 Inspektion 2021 Wilhelm-Kabus-Straße 21-35\\0600-6259_2021-07-21_Kennzeichnungsschild_Endsperre01.JPG	O:\\PDF_Prj\\0600-6200_0600-6299\\0600-6259 Inspektion 2021 Wilhelm-Kabus-Straße 21-35\\0600-6259_2021-07-21_Kennzeichnungsschild-Endsperre	\N	f	2021-07-21	1899-12-30 13:18:00	0	2021-07-21 14:24:03	-9	f	0	0	3	1	\N	\N
944851	2021-08-12	0	2021-08-12	1899-12-30 12:40:00	2021-08-12	1899-12-30 12:41:00	0	f	Bn	161	0	1	0	6006259	0	Mangel mittel	Beschreibung des Mangels	\N	\N	\N	f	2021-08-12	1899-12-30 12:44:00	3200	2021-08-12 12:45:00	-9	f	0	0	2	2	1	150m Podest
944852	2021-08-12	0	2021-08-12	1899-12-30 12:41:00	2021-08-12	1899-12-30 12:42:00	0	f	Bn	161	0	1	0	6006259	0	Mangel schwer	Beschreibung des Mangels	\N	\N	\N	f	2021-08-12	1899-12-30 12:45:00	3300	2021-08-12 12:45:01	-9	f	0	0	2	2	2	erstes podest
944853	2021-08-12	0	2021-08-12	1899-12-30 12:42:00	2021-08-12	1899-12-30 12:42:00	0	f	Bn	161	0	1	0	6006259	0	ohne Mangel	Beschreibung des Mangels	\N	\N	\N	f	2021-08-12	1899-12-30 12:45:00	3000	2021-08-12 12:45:11	-9	f	0	0	2	2	3	direkt am Eingang
\.


--
-- Data for Name: MGAUFTR; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."MGAUFTR" ("PjNr", "PjNr_HP", "PjTypID", "Status", "Status_HP", "AnzahlAuHProjekte", "MBG", "HP_RANr", "Verfolgung", "StONr", "VhNr", "SGNr", "PreisCode", "AuDatum", "AuForm", "ANG_Dat", "ANG_Sum", "ANG_Frei", "Netzbetreiber", "InKuNr", "InKuNrIndex", "EndKuNr", "EndKuNrIndex", "RAanKuNr", "RAanAnIndex", "VM_Orga_ID", "VM_ASP_ID", "RV_ID", "RV_Rabatt", "NeNr", "PjGrNr", "PjName", "PjInfo", "VLeitung", "PjLeitung", "Bauleitung", "BauteitungEXTERN", "AuftrNrEXTERN1", "AuftrNrEXTERN2", "AuftrNrEXTERN3", "AuftrNrEXTERN4", "AuftrNrEXTERN5", "AuftrDatEXTERN", "AuftrBestSAP", "LIEanEXT", "LIEanEXTIndex", "LIEanEXT_Info", "LTDatEXT", "Bem_INT", "Bem_EXT", "Baufrei", "MannStd", "DiffStd", "Max_Event_Dat", "Max_Event_Zeit", "Max_Event_KurzText", "Max_Mont_Dat", "Buget", "Buget_Dat", "UmsProg", "UmsProg_Art", "UmsProg_Dat", "Sum_STD", "Sum_STD_MP", "Sum_STD_KGZ_0", "Sum_STD_KGZ_1", "Sum_STD_KGZ_2", "Sum_STD_KGZ_3", "Sum_STD_KGZ_4", "Sum_STD_KGZ_5", "Sum_STD_KGZ_6", "Sum_STD_KGZ_8", "Sum_STD_ALP", "Sum_MAT", "Sum_RE", "Sum_RE_oA", "Sum_KAS", "Sum_RA", "Zahlungen_Pos_Sum", "Zahlungen_Neg_Sum", "Zahlungen_Anzahl", "DB", "Check_STD", "Check_MAT", "Check_RE", "Check_RA", "Plan_Start", "Plan_Ende", "Start", "Ende", "Bearbeitungszeit", "ÄndFLT", "FLT", "ÄndBZA", "BZA", "MatDat", "Aktiv", "Fertig", "BauInfo", "BereitZurAbnahme", "AbnahmeDat", "AbnahmeMangelOffen", "RestleistungOffen", "InspektMangelOffen", "BereitZurSR", "SR_Dat", "Prio_ID_Bau", "Länder_ID", "Std_Satz_Sonst", "Std_Satz_VW", "Std_Satz_BL", "Std_Satz_Mont", "Std_Satz_MontFremd", "Std_Satz_AKQ", "Std_Satz_CAD", "Std_Satz_Statik", "GKZ_Mat", "GKZ_Fremd", "GKZ_Kasse", "LB_ID", "initMP_PsNr", "initMP_Dat", "Montage_Info", "Montage_Info_KZL", "Montage_Prio", "Montage_Tage", "Montage_Mont", "Montage_Fremd", "istMBGPaar", "Material_Engpass", "Montage_Start_Wunsch", "Montage_Ende", "Montage_Forecast", "Montage_Sa_inkl", "KGZ_Ext_ID") FROM stdin;
6006259	\N	0	Ins	\N	\N	1	\N	t	5843	0	0	0	2021-07-21	mündl.	\N	0	\N	0	0	1	0	1	0	1	0	1	0	0	0	1000	Inspektion 2021: Wilhelm-Kabus-Straße 21-35	Inspektion Fahnenmast	\N	Ne	\N	\N	\N	\N	\N	\N	\N	\N	\N	9	1	\N	\N	\N	\N	\N	0	0	\N	1899-12-30 12:24:46	\N	\N	0	\N	0	\N	\N	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	0	\N	\N	\N	\N	\N	f	f	\N	f	\N	\N	\N	\N	f	\N	2	1	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	-9	0	\N	\N	\N	0	\N	\N	f	f	1	\N	\N	f	t	0
\.


--
-- Data for Name: STANDORT; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."STANDORT" ("StONr", "CreatedByPsNr", "StOaktiv", "TECH_Typ_ID", "StO_Typ_ID", "ESS_KAN", "InspektionErforderlich", "StONrBH", "BYNr", "BHNr", "StO_Suchgebiet", "Straße", "PLZ", "Ort", "Ortsteil", "Bezirk", "Region", "Bundesland_ID", "RegionZiffer", "StO_Inh_Info", "StO_ET", "StO_HV", "Beschreibung Telekom", "Beschreibung2", "AufbauFIRMA", "Beschreibung MBG", "InfoMBG", "GEO_STR", "GEO_HNr", "GEO_HNrZ", "GEO_Hoehe", "IMM_Höhe", "IMM_Hoehe_Qual_ID", "IMM_Typ", "IMM_Ges", "IMM_Dach", "PV_Dachneigung", "PV_AzimuthSüd", "StO_Status", "StO_Nutz_TMO", "StO_Nutz_MMO", "StO_Nutz_MCMM", "StO_Nutz_O2", "StO_Nutz_EPLUS", "StO_Nutz_SIG", "StO_MN_MMO", "StO_MN_Eplus", "StO_MN_VIAG", "StO_MN_Sonst", "StO_MN_Info", "StO_MN_Info_Dat", "DIENST_D1_900", "DIENST_D1_1800", "DIENST_D1_UMTS", "DIENST_C-Netz", "DIENST_Modacom", "DIENST_Sonst", "DIENST_Info", "ATR_Anz", "ATR_KLmax", "ATR_NLmax", "ATR_KL>10m", "ATR_HüTmax", "ATR_EWT_Info", "ANT_Konzept_ID", "ANT_GFK", "ANT_VF", "ANT_HF", "FertigDat", "UmbauDat", "Bearbeiter", "TuBuErforderlich", "InfoDatErforderlich", "TuBuRAUSmaxDat", "InfoTuBu", "StO_fertig", "InfoDatFertig", "StatikenATRda", "InfoDatATR", "StatikenGEBda", "InfoDatGEB", "FotosDa", "InfoDatFoto", "WegDa", "InfoDatWeg", "TuBuNEXTart", "SchildErf", "SchildBest-Alt", "SchildBest", "SchildMont", "01", "02", "03", "04", "05", "06", "07", "08", "Insp1996", "Insp1997", "Insp1998", "Insp1999", "Insp2000", "StONr_DFMG", "StONr_TMobile", "StONr_Vodafone", "StONr_EPlus", "StONr_O2", "StOName_Sonstige1", "StOName_Sonstige2", "StOName_DFMG", "StOName_TMobile", "StOName_Vodafone", "StOName_EPlus", "StOName_O2", "StOSuchgebiet_DFMG", "StOSuchgebiet_TMobile", "StOSuchgebiet_Vodafone", "StOSuchgebiet_EPlus", "StOSuchgebiet_O2", "SGNr_DFMG", "SGNr_TMobile", "SGNr_Vodafone", "SGNr_EPlus", "SGNr_O2", "BSNr_EPlus_Master", "BSNr_EPlus_UMTS", "BSNr_EPlus_GMS", "BSNr_EPlus_Erw1", "BSNr_EPlus_Erw2", "BSNr_O2_Master", "BSNr_O2_UMTS", "BSNr_O2_GMS", "BSNr_O2_Erw1", "BSNr_O2_Erw2", "StO_Status_Suche", "StO_Status_Kandidat", "StO_Status_ESS", "StO_Status_Planung", "StO_Status_Bau", "StO_Status_Demontiert", "StO_Status_Fremd", "StONr_BDBOS", "StONr_BDBOS_Brb", "StOName_BDBOS", "SGNr_BDBOS", "NENr_BDBOS_1", "NENr_BDBOS_2", "NENr_BDBOS_3", "NENr_BDBOS_4", "SGNr_PV", "StOSuchgebiet_PV", "SGNr_Taxi", "StOSuchgebiet_Taxi", "SGNr_Sigfox", "StOSuchgebiet_Sigfox", "StONr_PV", "Länder_ID", "AdminRegion2_ID", "Gemarkung", "Flur", "Flurstück", "istPVStO", "FLH", "DMS", "Windlast", "Schneelast", "NetzOrga_ID", "Netzimpedanz", "Netzeinspeisung", "Netz_Einschr", "Netzklasse", "Notstromaggregat", "Notstrom_typ", "ET_Typ_ID", "DSL", "StromAnschluss", "EntfernungZuMBG") FROM stdin;
5843	147	t	0	0	t	f	\N	\N	1	\N	Wilhelm-Kabus-Straße 21-35	10829	Berlin	\N	\N	\N	3	0	\N	9	9	\N	\N	MBG	Druckhaus Mitte	\N	\N	\N	\N	49	\N	\N	\N	\N	\N	\N	-99	\N	\N	\N	\N	\N	\N	\N	f	f	f	\N	\N	\N	f	f	f	f	f	\N	\N	0	0	0	f	0	\N	0	f	f	f	\N	\N	0	t	\N	\N	\N	f	\N	f	\N	f	\N	f	\N	f	\N	NEU	f	\N	\N	\N	t	t	t	t	t	t	t	t	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	0	0	0	0	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	0	0	0	0	0	0	0	\N	\N	\N	\N	\N	\N	\N	\N	0	\N	0	\N	0	\N	\N	1	0	\N	\N	\N	t	f	f	\N	\N	\N	\N	\N	\N	0	-9	\N	1	-9	-9	\N
\.


--
-- Name: events_index_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.events_index_seq', 1, false);


--
-- Name: Events Events_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Events"
    ADD CONSTRAINT "Events_pkey" PRIMARY KEY ("Index");


--
-- Name: MGAUFTR MGAUFTR_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."MGAUFTR"
    ADD CONSTRAINT "MGAUFTR_pkey" PRIMARY KEY ("PjNr");


--
-- Name: STANDORT STANDORT_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."STANDORT"
    ADD CONSTRAINT "STANDORT_pkey" PRIMARY KEY ("StONr");


--
-- Name: Events Events_PjNr_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Events"
    ADD CONSTRAINT "Events_PjNr_fkey" FOREIGN KEY ("PjNr") REFERENCES public."MGAUFTR"("PjNr") ON UPDATE CASCADE;


--
-- Name: MGAUFTR MGAUFTR_PjNr_HP_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."MGAUFTR"
    ADD CONSTRAINT "MGAUFTR_PjNr_HP_fkey" FOREIGN KEY ("PjNr_HP") REFERENCES public."MGAUFTR"("PjNr") ON UPDATE CASCADE;


--
-- Name: MGAUFTR MGAUFTR_StONr_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."MGAUFTR"
    ADD CONSTRAINT "MGAUFTR_StONr_fkey" FOREIGN KEY ("StONr") REFERENCES public."STANDORT"("StONr") ON UPDATE CASCADE;


--
-- PostgreSQL database dump complete
--

