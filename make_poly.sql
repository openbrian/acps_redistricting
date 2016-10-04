set search_path to acps_redistricting, alexandria, census_2010, public;


select addgeometrycolumn( 'alexandria', 'bld_y', 'center', '4326', 'POINT', 2 );
update bld_y set center = st_centroid( wkb_geometry );
create index idx_bld_y_center on bld_y using gist(center);
vacuum analyze bld_y;




--shp2pgsql -s 4326 -c -g geom -I tabblock2010_51_pophu.shp census_2010.tabblock | psql gis

create index idx_tabblock_countyfp10 on tabblock(countyfp10);
cluster tabblock using idx_tabblock_countyfp10;
alter table tabblock add column area float;
update tabblock set area = st_area(geom::geography);
alter table tabblock alter column area set not null;

alter table tabblock add column density float;
-- non have area = 0
update tabblock set density = pop10/area;
alter table tabblock alter column density set not null;

-- Add the number of units to each block because housing10 is innacurate.
alter table tabblock add column units integer;
update tabblock blk
set units = sel.units
from (
	select blk.gid, coalesce( sum(bunits), 0 ) as units
	from tabblock blk
	join bld_y bld on st_within( center, blk.geom )
	group by blk.gid
	) sel
where blk.gid = sel.gid;



 -- Any overlaps?
select *
from
	(
	select *
	from census_2010.tabblock
	where countyfp10='510'
	) a
join
	(
	select *
	from census_2010.tabblock
	where countyfp10='510'
	) b on st_overlaps(a.geom, b.geom);
-- no
 

drop view if exists make_district_poly;

create view make_district_poly as 
select id, st_multi( st_collect( st_setsrid( geom, 4326 ) ) ) as geom
from
	(
	select id, (st_dump(st_polygonize(ls))).path, st_astext((st_dump(st_polygonize(ls))).geom) as geom 
	from
	 	(
	 	select r.id, linestring ls
	 	from acps_relations r
	 	join acps_relation_members rm on r.id = rm.relation_id
	 	join acps_ways w on rm.member_id = w.id
	 	order by sequence_id
	 	) as foo
	group by id
	) as g
group by id;






drop table if exists acps_district;
create table acps_district as select * from make_district_poly;
alter table acps_district add primary key (id);
create index idx_acps_district_geom on acps_district using gist(geom);


-- Any overlaps?
select *
from acps_district a
join acps_district b on st_overlaps(a.geom,b.geom);
-- no



drop table if exists bld_district;
-- TODO: Use centroid of building to avoid loosing buildings that are
-- not fully in a single district.  Or fix district boundarys to not
-- slice buildings.
create table bld_district as
select b.objectid as bld, d.id as district
from alexandria.bld_y b
join acps_district d on st_within( b.wkb_geometry, d.geom )
where b.buse = 1;


select district, count(*) from bld_district group by district;
select bld, count(*) from bld_district group by bld having count(*) > 1;




drop table if exists bld_unit;
create table bld_unit as 
select b.objectid as bld, gs.unit from alexandria.bld_y b
join generate_series(1,1000) as gs(unit) on gs.unit <= b.bunits;



drop table if exists bld_unit_district;
create table bld_unit_district as
select *
from bld_district bd
join bld_unit using (bld);

select district, count(*) from bld_unit_district group by district;






-- Some districts clearly cut blocks into parts.

create sequence seq_district_block_id;

-- Merge the acps_districta and tabblock layers
drop table if exists district_block;
create table district_block as
select nextval('seq_district_block_id') as id, name, gid, st_multi(geom) as geom, type
from (
	select name, gid, (st_dump(st_intersection(d.geom, b.geom))).geom as geom, 'i'::char as type
	from (select * from acps_district where year = 2016) d
	join (select * from tabblock where countyfp10 = '510') b
	 	on st_intersects(d.geom, b.geom)
	) s
where st_geometrytype(geom) = 'ST_Polygon';

insert into district_block
select nextval('seq_district_block_id'), name, null, st_multi(st_difference(d.geom, b.geom)) as geom, 'd'
from (select * from acps_district where year = 2016) d
join (select st_union(geom) as geom from tabblock where countyfp10 = '510') b
	on st_overlaps(d.geom, b.geom);

insert into district_block
select nextval('seq_district_block_id'), null, gid, st_multi(st_difference(b.geom, d.geom)) as geom, 'b'
from (select st_union(geom) as geom from acps_district where year = 2016) d
join (select * from tabblock where countyfp10 = '510') b
	on st_overlaps(d.geom, b.geom);


insert into geometry_columns
values ('', 'acps_redistricting', 'district_block', 'geom', 2, 4326, 'MULTIPOLYGON');

alter table district_block add primary key (id);
--create unique index idx_district_block_name_gid on district_block (name, gid);
select name, gid, count(*)
from district_block
group by name, gid
having 1 < count(*);
-- whoa, 92 rows



-- For each district_block, what percentage of people live in it.
-- Divide the population by number of units in that block.
alter table district_block add column units integer;
update district_block set units = 0;
alter table district_block alter column units set not null;


-- Find the number of units in each district_block.
update district_block db
set units = sel.units
from (
	select db.id, coalesce( sum(bunits), 0 ) as units
	from district_block db
	join bld_y bld on st_within( center, db.geom )
	group by db.id
	) sel
where db.id = sel.id;


select count(*) from district_block;
-- TODO: verify this number



-- Find the population on each district_block.
alter table district_block add column pop10 integer;
update district_block db
set pop10 = sel.pop10
from (
	select db.id
	 	, blk.pop10
	 	, blk.units
	 	, db.name, db.gid
	 	, db.units
	 	, case when blk.units = 0 then 0
	 	       else blk.pop10 * (db.units/blk.units::float)
	 	  end as pop
	from tabblock blk
	join district_block db using (gid)
	) as sel
where db.id = sel.id;







