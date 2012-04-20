INSERT INTO manufacturers(name) values('IBM');
INSERT INTO manufacturers(name) values('Dell');
INSERT INTO manufacturers(name) values('HP');
INSERT INTO manufacturers(name) values('Cisco');

INSERT INTO models (name,manufacturer_id) VALUES('336','1');
INSERT INTO models (name,manufacturer_id) VALUES('C3750G-24TS','4');
INSERT INTO models (name,manufacturer_id) VALUES('PowerEdge R410','2');
INSERT INTO models (name,manufacturer_id) VALUES('PowerEdge R710','2');

INSERT INTO locations (name) VALUES('Main server room');
INSERT INTO locations (name) VALUES('Disaster Recovery Site');
INSERT INTO locations (name) VALUES('Main Office Building');

-- status table should already be populated by creation script

INSERT INTO hosts (name,description,location_id,status_id,asset,serial,model_id) VALUES ('lisa','dedicated DNS host','1','1','t-38749-tt','32479','1');
INSERT INTO hosts (name,description,location_id,status_id,asset,serial,model_id) VALUES ('bart','dedicated DNS host','1','1','t-38748-tt','32478','1');
INSERT INTO hosts (name,description,location_id,status_id,asset,serial,model_id) VALUES ('maggie','dedicated DNS host','1','1','t-38747-tt','32477','1');

INSERT INTO hosts (name,description,location_id,status_id,asset,serial,model_id) VALUES ('oil','dedicated DHCP host','1','1','t-5674-tt','5367','4');
INSERT INTO hosts (name,description,location_id,status_id,asset,serial,model_id) VALUES ('water','dedicated DHCP host','1','1','t-5673-tt','5366','4');

INSERT INTO interfaces (host_id,address,lastresolvedfqdn) VALUES ('1','192.168.1.1','lisa.admin.example.com');
INSERT INTO interfaces (host_id,address,lastresolvedfqdn) VALUES ('1','192.168.2.1','ns1.example.com');
INSERT INTO interfaces (host_id,address,lastresolvedfqdn) VALUES ('2','192.168.1.2','bart.admin.example.com');
INSERT INTO interfaces (host_id,address,lastresolvedfqdn) VALUES ('2','192.168.2.2','ns2.example.com');
INSERT INTO interfaces (host_id,address,lastresolvedfqdn) VALUES ('3','192.168.1.3','maggie.admin.example.com');
INSERT INTO interfaces (host_id,address,lastresolvedfqdn) VALUES ('3','192.168.2.3','ns3.example.com');

INSERT INTO sshkeys(host_id, fingerprint) VALUES ('1','aa:bb:cc:dd:0b:50:5c:e1:da:2d:6f:5b:65:82:94:c5');
INSERT INTO sshkeys(host_id, fingerprint) VALUES ('2','bb:bb:cc:ee:0b:50:5c:e1:aa:2d:4f:5b:65:42:94:c5');
INSERT INTO sshkeys(host_id, fingerprint) VALUES ('2','ff:bb:ac:ee:0b:20:5c:e1:ab:2d:2f:5b:65:42:a4:a5');
UPDATE interfaces SET lastresolveddate = NOW();

UPDATE interfaces SET isprimary=true WHERE id=2;
UPDATE interfaces SET isprimary=true WHERE id=4;

