DROP DATABASE inventory;
CREATE DATABASE inventory;
\c inventory;

CREATE USER demouser WITH PASSWORD 'replace-with-pwgen';
CREATE USER writeuser WITH PASSWORD 'replace-with-pwgen';

CREATE TABLE suppliers (
    id      serial NOT NULL,
    name    character varying UNIQUE NOT NULL,
    website    character varying,
    techphone  character varying,
    salesphone character varying,
    address    character varying,
    PRIMARY KEY(id)
);

CREATE TABLE contacts (
    id            serial NOT NULL,
    supplier_id   integer NOT NULL,
    name          character varying NOT NULL,
    address       character varying,
    telephone     character varying,
    role          character varying,
    notes         character varying,
    PRIMARY KEY(id)
);
ALTER TABLE ONLY contacts ADD CONSTRAINT contacts_supplier_id_fkey FOREIGN KEY (supplier_id) REFERENCES suppliers(id);

CREATE TABLE invoices (
    id            serial NOT NULL,
    supplier_id   integer NOT NULL,
    date          date DEFAULT NOW(),
    description   character varying,
    purchaser_id  integer NOT NULL,
    signitory_id  integer NOT NULL,
    ponumber      character varying,
    reqnumber     character varying,
    costcentre    character varying,
    natacct       character varying,
    totalcost     NUMERIC(10,2),
    PRIMARY KEY(id)
);
ALTER TABLE ONLY invoices ADD CONSTRAINT invoices_supplier_id_fkey FOREIGN KEY (supplier_id) REFERENCES suppliers(id);
ALTER TABLE ONLY invoices ADD CONSTRAINT invoices_purchaser_id_fkey FOREIGN KEY (purchaser_id) REFERENCES contacts(id);
ALTER TABLE ONLY invoices ADD CONSTRAINT invoices_signitory_id_fkey FOREIGN KEY (signitory_id) REFERENCES contacts(id);

CREATE TABLE servicelevels (
    id            serial NOT NULL,
    name          character varying NOT NULL,
    description   character varying,
    supplier_id   integer DEFAULT NULL,
    PRIMARY KEY(id)
);
ALTER TABLE ONLY servicelevels ADD CONSTRAINT servicelevels_supplier_id_fkey FOREIGN KEY (supplier_id) REFERENCES suppliers(id);

CREATE TABLE contracts (
    id            serial NOT NULL,
    name          character varying NOT NULL,
    serial        character varying,
    startdate     character varying,
    enddate       character varying,
    invoice_id      integer DEFAULT NULL,
    servicelevel_id integer DEFAULT NULL,
    PRIMARY KEY(id)
);
ALTER TABLE ONLY contracts ADD CONSTRAINT contracts_invoice_id_fkey FOREIGN KEY (invoice_id) REFERENCES invoices(id);
ALTER TABLE ONLY contracts ADD CONSTRAINT contracts_servicelevel_id_fkey FOREIGN KEY (servicelevel_id) REFERENCES servicelevels(id);

CREATE TABLE manufacturers (
    id    serial NOT NULL,
    name  character varying UNIQUE NOT NULL,
    PRIMARY KEY(id)
);

CREATE TABLE models (
    id               serial NOT NULL,
    name             character varying NOT NULL,
    manufacturer_id  integer NOT NULL,
    dateeol          date,
    PRIMARY KEY(id)
);
ALTER TABLE ONLY models ADD CONSTRAINT models_manufacturer_id_fkey FOREIGN KEY (manufacturer_id) REFERENCES manufacturers(id);

CREATE TABLE locations (
    id      serial NOT NULL,
    name    character varying UNIQUE NOT NULL,
    PRIMARY KEY(id)
);

CREATE TABLE status (
    id          serial NOT NULL,
    state       character varying UNIQUE NOT NULL,
    description character varying,
    PRIMARY KEY(id)
);

INSERT INTO status(state,description) VALUES ('ACTIVE', 'Currently live');
INSERT INTO status(state,description) VALUES ('INACTIVE', 'Currently not live');
INSERT INTO status(state,description) VALUES ('DECOMMISIONED', 'Thrown away');

CREATE TABLE hosts (
    id          serial NOT NULL,
    name        character varying UNIQUE,
    description character varying,
    location_id integer NOT NULL,
    status_id   integer NOT NULL,
    asset       character varying,
    serial      character varying,
    model_id    integer NOT NULL,
    invoice_id  integer,
    lastchecked date DEFAULT NOW(),
    PRIMARY KEY(id)
);
ALTER TABLE ONLY hosts ADD CONSTRAINT hosts_location_id_fkey FOREIGN KEY (location_id) REFERENCES locations(id);
ALTER TABLE ONLY hosts ADD CONSTRAINT hosts_model_id_fkey FOREIGN KEY (model_id) REFERENCES models(id);
ALTER TABLE ONLY hosts ADD CONSTRAINT hosts_status_id_fkey FOREIGN KEY (status_id) REFERENCES status(id);
ALTER TABLE ONLY hosts ADD CONSTRAINT hosts_invoice_id_fkey FOREIGN KEY (invoice_id) REFERENCES invoices(id);

CREATE TABLE photos (
    id      serial NOT NULL,
    host_id       integer NOT NULL,
    url     character varying NOT NULL,
    PRIMARY KEY(id)
);
ALTER TABLE ONLY photos ADD CONSTRAINT photos_host_id_fkey FOREIGN KEY (host_id) REFERENCES hosts(id);

CREATE TABLE hostgroups (
    id      serial NOT NULL,
    name        character varying UNIQUE NOT NULL,
    description character varying,
    bash        character varying UNIQUE DEFAULT NULL,
    nagios      character varying UNIQUE DEFAULT NULL,
    PRIMARY KEY(id)
);


CREATE TABLE hosts_to_hostgroups (
    id         serial NOT NULL,
    hostgroup_id    integer NOT NULL,
    host_id     integer NOT NULL,
    PRIMARY KEY(id)
);
ALTER TABLE ONLY hosts_to_hostgroups ADD CONSTRAINT hosts_to_hostgroups_hostgroup_id_fkey FOREIGN KEY (hostgroup_id) REFERENCES hostgroups(id);
ALTER TABLE ONLY hosts_to_hostgroups ADD CONSTRAINT hosts_to_hostgroups_host_id_fkey FOREIGN KEY (host_id) REFERENCES hosts(id);

CREATE TABLE protocols (
    id    serial NOT NULL,
    shortname  character varying NOT NULL,
    longname   character varying NOT NULL,
    PRIMARY KEY(id)
);
INSERT INTO protocols(shortname,longname) VALUES ('TCP','Listening on Transmission Control Protocol only');
INSERT INTO protocols(shortname,longname) VALUES ('UDP','Listening on User Datagram Protocol only');
INSERT INTO protocols(shortname,longname) VALUES ('ALLNET','Listening on all network protocols');
INSERT INTO protocols(shortname,longname) VALUES ('UNIXLOOPBACK','Listening via loopback network socket');
INSERT INTO protocols(shortname,longname) VALUES ('UNIXSOCKET','Listening on a internal socket');
INSERT INTO protocols(shortname,longname) VALUES ('NONE','No idea if this will be useful');

CREATE TABLE hosts_to_upshost (
    id        serial NOT NULL,
    host_id  integer NOT NULL,
    ups_id   integer NOT NULL,
    PRIMARY KEY(id)
);
ALTER TABLE ONLY hosts_to_upshost ADD CONSTRAINT hosts_to_hostups_host_id_fkey FOREIGN KEY (host_id) REFERENCES hosts(id);
ALTER TABLE ONLY hosts_to_upshost ADD CONSTRAINT hosts_to_hostups_ups_id_fkey FOREIGN KEY (ups_id) REFERENCES hosts(id);

CREATE TABLE services (
    id          serial NOT NULL,
    shortname   character varying UNIQUE NOT NULL,
    longname    character varying UNIQUE DEFAULT NULL,
    description character varying,
    port        integer,
    protocol_id integer,
    PRIMARY KEY(id)
);

INSERT INTO services(shortname,longname,description,port,protocol_id) VALUES ('NTP','Network Time Protocol','Time syncronisation','123','2');
INSERT INTO services(shortname,longname,description,port,protocol_id) VALUES ('DNS','Domain Name Service','Name resolution','53','2');
ALTER TABLE ONLY services ADD CONSTRAINT services_protocol_id_fkey FOREIGN KEY (protocol_id) REFERENCES protocols(id);

CREATE TABLE interfaces (
    id                 serial NOT NULL,
    host_id           integer NOT NULL,
    address            cidr NOT NULL,
    lastresolvedfqdn   character varying,
    lastresolveddate   date,
    PRIMARY KEY(id)
);

ALTER TABLE ONLY interfaces ADD CONSTRAINT interfaces_host_id_fkey FOREIGN KEY (host_id) REFERENCES hosts(id);

CREATE TABLE sshkeys (
    id           serial NOT NULL,
    host_id      integer NOT NULL,
    fingerprint  character varying NOT NULL,
    PRIMARY KEY(id)
);
ALTER TABLE ONLY sshkeys ADD CONSTRAINT sshkeys_host_id_fkey FOREIGN KEY (host_id) REFERENCES hosts(id);

CREATE TABLE interfaces_to_services (
    id             serial NOT NULL,
    service_id     integer NOT NULL,
    interface_id   integer NOT NULL,
    port           integer NOT NULL,
    protocol_id    integer NOT NULL,
    PRIMARY KEY(id)
);
ALTER TABLE ONLY interfaces_to_services ADD CONSTRAINT interfaces_to_services_service_id_fkey FOREIGN KEY (service_id) REFERENCES services(id);
ALTER TABLE ONLY interfaces_to_services ADD CONSTRAINT interfaces_to_services_protocol_id_fkey FOREIGN KEY (protocol_id) REFERENCES protocols(id);

CREATE TABLE voipbackends (
    id     serial NOT NULL,
    name   character varying NOT NULL UNIQUE,
    PRIMARY KEY(id)
);
INSERT INTO voipbackends(name) VALUES ('Cisco');
INSERT INTO voipbackends(name) VALUES ('Siemens');

CREATE TABLE voipconnectiontypes (
    id     serial NOT NULL,
    name   character varying NOT NULL UNIQUE,
    PRIMARY KEY(id)
);
INSERT INTO voipconnectiontypes(name) VALUES ('Frodo');
INSERT INTO voipconnectiontypes(name) VALUES ('Secure');

CREATE TABLE voipnetworks (
    id     serial NOT NULL,
    number integer NOT NULL,
    name   character varying NOT NULL,
    PRIMARY KEY(id)
);

CREATE TABLE vlans (
    id     serial NOT NULL,
    name   character varying UNIQUE NOT NULL,
    number integer UNIQUE NOT NULL,
    PRIMARY KEY(id)
);

CREATE TABLE voipswitches (
    id             serial NOT NULL,
    host_id        integer NOT NULL,
    vlan_id        integer NOT NULL,
    switch_number  integer NOT NULL,
    voipnetwork_id integer NOT NULL,
    voipbackend_id        integer NOT NULL,
    voipconnectiontype_id integer NOT NULL,
    PRIMARY KEY(id)
);
ALTER TABLE ONLY voipswitches ADD CONSTRAINT voipswitches_host_id_fkey FOREIGN KEY (host_id) REFERENCES hosts(id);
ALTER TABLE ONLY voipswitches ADD CONSTRAINT voipswitches_vlan_id_fkey FOREIGN KEY (vlan_id) REFERENCES vlans(id);
ALTER TABLE ONLY voipswitches ADD CONSTRAINT voipswitches_voipnetwork_id_fkey FOREIGN KEY (voipnetwork_id) REFERENCES voipnetworks(id);
ALTER TABLE ONLY voipswitches ADD CONSTRAINT voipswitches_voipbackend_id_fkey FOREIGN KEY (voipbackend_id) REFERENCES voipbackends(id);
ALTER TABLE ONLY voipswitches ADD CONSTRAINT voipswitches_voipconnectiontype_id_fkey FOREIGN KEY (voipconnectiontype_id) REFERENCES voipconnectiontypes(id);


GRANT select ON hostgroups TO demouser;
GRANT select ON interfaces_to_services TO demouser;
GRANT select ON hosts TO demouser;
GRANT select ON interfaces TO demouser;
GRANT select ON hosts_to_hostgroups TO demouser;
GRANT select ON services TO demouser;
GRANT select ON locations TO demouser;
GRANT select ON sshkeys TO demouser;
GRANT select ON photos TO demouser;
GRANT select ON manufacturers TO demouser;
GRANT select ON models TO demouser;
GRANT select ON voipbackends TO demouser;
GRANT select ON voipconnectiontypes TO demouser;
GRANT select ON voipnetworks TO demouser;
GRANT select ON vlans TO demouser;
GRANT select ON voipswitches TO demouser;
GRANT select ON status TO demouser;
GRANT select ON protocols TO demouser;
GRANT select ON hosts_to_upshost TO demouser;
GRANT select ON suppliers TO demouser;
GRANT select ON servicelevels TO demouser;

GRANT select ON contacts TO demouser;
GRANT select ON invoices TO demouser;
GRANT select ON contracts TO demouser;

GRANT select ON hostgroups_id_seq TO demouser;
GRANT select ON interfaces_to_services_id_seq TO demouser;
GRANT select ON hosts_id_seq TO demouser;
GRANT select ON interfaces_id_seq TO demouser;
GRANT select ON hosts_to_hostgroups_id_seq TO demouser;
GRANT select ON services_id_seq TO demouser;
GRANT select ON locations_id_seq TO demouser;
GRANT select ON sshkeys_id_seq TO demouser;
GRANT select ON photos_id_seq TO demouser;
GRANT select ON manufacturers_id_seq TO demouser;
GRANT select ON models_id_seq TO demouser;
GRANT select ON voipbackends_id_seq TO demouser;
GRANT select ON voipconnectiontypes_id_seq TO demouser;
GRANT select ON voipnetworks_id_seq TO demouser;
GRANT select ON vlans_id_seq TO demouser;
GRANT select ON voipswitches_id_seq TO demouser;
GRANT select ON status_id_seq TO demouser;
GRANT select ON protocols_id_seq TO demouser;
GRANT select ON hosts_to_upshost_id_seq TO demouser;
GRANT select ON suppliers_id_seq TO demouser;
GRANT select ON servicelevels_id_seq TO demouser;

GRANT select ON contacts_id_seq TO demouser;
GRANT select ON invoices_id_seq TO demouser;
GRANT select ON contracts_id_seq TO demouser;


GRANT select,insert,update,delete ON hostgroups TO writeuser;
GRANT select,insert,update,delete ON interfaces_to_services TO writeuser;
GRANT select,insert,update,delete ON hosts TO writeuser;
GRANT select,insert,update,delete ON interfaces TO writeuser;
GRANT select,insert,update,delete ON hosts_to_hostgroups TO writeuser;
GRANT select,insert,update,delete ON services TO writeuser;
GRANT select,insert,update,delete ON locations TO writeuser;
GRANT select,insert,update,delete ON sshkeys TO writeuser;
GRANT select,insert,update,delete ON photos TO writeuser;
GRANT select,insert,update,delete ON manufacturers TO writeuser;
GRANT select,insert,update,delete ON models TO writeuser;
GRANT select,insert,update,delete ON voipbackends TO writeuser;
GRANT select,insert,update,delete ON voipconnectiontypes TO writeuser;
GRANT select,insert,update,delete ON voipnetworks TO writeuser;
GRANT select,insert,update,delete ON vlans TO writeuser;
GRANT select,insert,update,delete ON voipswitches TO writeuser;
GRANT select,insert,update,delete ON status TO writeuser;
GRANT select,insert,update,delete ON protocols TO writeuser;
GRANT select,insert,update,delete ON hosts_to_upshost TO writeuser;
GRANT select,insert,update,delete ON suppliers TO writeuser;
GRANT select,insert,update,delete ON servicelevels TO writeuser;

GRANT select,insert,update,delete ON contacts TO writeuser;
GRANT select,insert,update,delete ON invoices TO writeuser;
GRANT select,insert,update,delete ON contracts TO writeuser;

GRANT all ON hostgroups_id_seq TO writeuser;
GRANT all ON interfaces_to_services_id_seq TO writeuser;
GRANT all ON hosts_id_seq TO writeuser;
GRANT all ON interfaces_id_seq TO writeuser;
GRANT all ON hosts_to_hostgroups_id_seq TO writeuser;
GRANT all ON services_id_seq TO writeuser;
GRANT all ON locations_id_seq TO writeuser;
GRANT all ON sshkeys_id_seq TO writeuser;
GRANT all ON photos_id_seq TO writeuser;
GRANT all ON manufacturers_id_seq TO writeuser;
GRANT all ON models_id_seq TO writeuser;
GRANT all ON voipbackends_id_seq TO writeuser;
GRANT all ON voipconnectiontypes_id_seq TO writeuser;
GRANT all ON voipnetworks_id_seq TO writeuser;
GRANT all ON vlans_id_seq TO writeuser;
GRANT all ON voipswitches_id_seq TO writeuser;
GRANT all ON status_id_seq TO writeuser;
GRANT all ON protocols_id_seq TO writeuser;
GRANT all ON hosts_to_upshost_id_seq TO writeuser;
GRANT all ON suppliers_id_seq TO writeuser;
GRANT all ON servicelevels_id_seq TO writeuser;

GRANT all ON contacts_id_seq TO writeuser;
GRANT all ON invoices_id_seq TO writeuser;
GRANT all ON contracts_id_seq TO writeuser;
