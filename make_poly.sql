set search_path to acps_redistricting, alexandria, alex_pgr, census_2010, public;

-- http://apt.postgresql.org/pub/repos/apt/pool/main/p/pgrouting/

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
select id as osm_relation_id, name, 2016 as year, st_multi( st_collect( st_setsrid( geom, 4326 ) ) ) as geom
from
	(
	select id, name, (st_dump(st_polygonize(ls))).path, st_astext((st_dump(st_polygonize(ls))).geom) as geom 
	from
	 	(
	 	select r.id, r.tabs->'name' as name, linestring ls
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
update acps_district set name = 'Jefferson-Houston' where name = 'Jefferson Houston';
alter table acps_district add primary key (name, year);

create index idx_acps_district_geom on acps_district using gist(geom);

-- Any overlaps?
select *
from acps_district a
join acps_district b on st_overlaps(a.geom,b.geom);
-- no


insert into acps_district (name, year)
select name, 2019
from acps_district;

insert into acps_district (name, year) values ('New ES', 2019);

alter table acps_district add column k5_capacity integer;
update acps_district set k5_capacity = 500 where year = 2016 and name='Charles Barrett';
update acps_district set k5_capacity = 371 where year = 2016 and name='Cora Kelly';
update acps_district set k5_capacity = 554 where year = 2016 and name='Douglas MacArthur';
update acps_district set k5_capacity = 368 where year = 2016 and name='George Mason';
update acps_district set k5_capacity = 756 where year = 2016 and name='James K. Polk';
update acps_district set k5_capacity = 407 where year = 2016 and name='Jefferson-Houston';
update acps_district set k5_capacity = 634 where year = 2016 and name='John Adams';
update acps_district set k5_capacity = 375 where year = 2016 and name='Lyles-Crouch';
update acps_district set k5_capacity = 350 where year = 2016 and name='Matthew Maury';
update acps_district set k5_capacity = 755 where year = 2016 and name='Mount Vernon';
update acps_district set k5_capacity = 592 where year = 2016 and name='Patrick Henry';
update acps_district set k5_capacity = 620 where year = 2016 and name='Samuel Tucker';
update acps_district set k5_capacity = 716 where year = 2016 and name='William Ramsay';
update acps_district set k5_capacity = 500 where year = 2019 and name='Charles Barrett';
update acps_district set k5_capacity = 371 where year = 2019 and name='Cora Kelly';
update acps_district set k5_capacity = 775 where year = 2019 and name='Douglas MacArthur';
update acps_district set k5_capacity = 368 where year = 2019 and name='George Mason';
update acps_district set k5_capacity = 850 where year = 2019 and name='James K. Polk';
update acps_district set k5_capacity = 407 where year = 2019 and name='Jefferson-Houston';
update acps_district set k5_capacity = 595 where year = 2019 and name='John Adams';
update acps_district set k5_capacity = 375 where year = 2019 and name='Lyles-Crouch';
update acps_district set k5_capacity = 350 where year = 2019 and name='Matthew Maury';
update acps_district set k5_capacity = 755 where year = 2019 and name='Mount Vernon';
update acps_district set k5_capacity = 728 where year = 2019 and name='Patrick Henry';
update acps_district set k5_capacity = 620 where year = 2019 and name='Samuel Tucker';
update acps_district set k5_capacity = 716 where year = 2019 and name='William Ramsay';
update acps_district set k5_capacity = 638 where year = 2019 and name='New ES';
select * from acps_district where k5_capacity is null;
alter table acps_district alter column k5_capacity set not null;



-- If new buildings are created over time, then we will need to join on year too.
drop table if exists bld_district;
-- TODO: Use centroid of building to avoid loosing buildings that are
-- not fully in a single district.  Or fix district boundarys to not
-- slice buildings.
create table bld_district as
select b.objectid as bld, d.year, d.name
from alexandria.bld_y b
join acps_district d on st_within( b.wkb_geometry, d.geom )
where b.buse = 1
;
alter table bld_district add primary key (bld);

select year, name, count(*) from bld_district group by year, name;
select bld, count(*) from bld_district group by bld having count(*) > 1;


-- Any buildings missing?
select st_astext(st_centroid(wkb_geometry)) as center, *
from alexandria.bld_y
where buse = 1
  and objectid not in
        (
        select bld
        from bld_district
        )
order by st_x(st_centroid(wkb_geometry));

select district, count(*) from bld_district group by district;
select bld, count(*) from bld_district group by bld having count(*) > 1;




--Enumerate all the units.
drop sequence if exists seq_bld_unit;
create sequence seq_bld_unit;
drop table if exists bld_unit;
create table bld_unit as 
select nextval('seq_bld_unit') as id, b.objectid as bld, gs.unit
from alexandria.bld_y b
join generate_series(1,1000) as gs(unit) on gs.unit <= b.bunits;


alter table bld_unit add primary key (id);
alter table bld_unit add constraint bld_fk foreign key (bld) references alexandria.bld_y(objectid);





drop view if exists bld_unit_district;
create view bld_unit_district as
select *
from bld_district bd
join bld_unit using (bld);

select year, name, count(*) from bld_unit_district group by year, name;




-- just for viewing purposes
create table bld_district_geom as
select distinct bld_y.objectid, bld_y.wkb_geometry, bud.district
from bld_unit_district bud join alexandria.bld_y on bud.bld = bld_y.objectid
;

alter table bld_district_geom add primary key (objectid);
create index bld_district_geom_geom on bld_district_geom using gist(wkb_geometry);





-- Some districts clearly cut blocks into parts.

create sequence seq_district_block_id;

-- Merge the acps_districta and tabblock layers.
drop table if exists district_block;
create table district_block as
select nextval('seq_district_block_id') as id, name, gid, st_multi(geom) as geom, type
from    (
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


alter table district_block add column area double precision;
update district_block set area = st_area(geom::geography);


-- What's the smallest district_block that contains a building?
select db.id, area
from district_block db
join (select * from bld_y where buse = 1) bld on st_within( bld.center, db.geom )
order by area
limit 1;
-- id   | 4615
-- area | 1073.89429050281
-- About 1/8th of a city block in Old Town.



-- Delete all the district_blocks smaller than that, especially the slivers
-- generated from intersecting the census blocks and the districts.
create table district_block_small as
select *
from district_block
where area <
    (
    select min(area)
    from district_block db
    join (select * from bld_y where buse = 1) bld on st_within( bld.center, db.geom )
    );
delete from district_block where id in (select id from district_block_small);



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
set pop10 = sel.pop
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




alter table district_block add column pop10_pct float;
update district_block db
set pop10_pct = pop10 / sub.total
from (
	select sum(pop10)::float as total
	from district_block
	) sub;


alter table district_block add column enrollment int;
update district_block db
set enrollment = round(pop10_pct * 8048);

select sum(enrollment) from district_block;
-- 8052

select addgeometrycolumn( 'acps_redistricting', 'district_block', 'center', '4326', 'POINT', 2 );
update district_block set center = st_centroid( geom );
create index idx_district_block_center on district_block using gist(center);
vacuum analyze district_block;



-- How many district_blocks have multiple types of housing.
select id, count(*) as number_of_types, array_agg(btype), array_agg(c) as count
from	(
	select btype, db.id, count(*) as c
	from (select * from bld_y where buse=1) b
	join district_block db on st_within(b.center, db.geom)
	group by db.id, btype
	) s
group by id
order by number_of_types desc;
-- Ans: a lot


alter table district_block add column color int;
update district_block set color = id % 7;
alter table district_block alter column color set not null;



select id, count(*)
from
        (
        select id
        from block, (
                select floor(35*random()) as r
                from generate_series(1,350)
                ) as rand
        where min <= rand.r and rand.r < max
        ) as f
group by id
order by id;


-- TODO: break down units by type, get the percent per type.


-- source: Long Range Educational Facilities Plan June 2015
create table unit_type
	( id serial primary key
	, name text not null unique
	, students_per_unit numeric
	);
insert into unit_type (name, students_per_unit) values ('single-family detached', '0.2');
insert into unit_type (name, students_per_unit) values ('townhouse/duplex', '0.1');
insert into unit_type (name, students_per_unit) values ('low-rise apartment/condo', '0.03');
insert into unit_type (name, students_per_unit) values ('midrise apartment/condo', '0.03');
insert into unit_type (name, students_per_unit) values ('highrise apartmnet/condo', '0.03');
insert into unit_type (name, students_per_unit) values ('public housing', '1.0');
insert into unit_type (name, students_per_unit) values ('other income-restricted housing', '0.6');

insert into unit_type (name, students_per_unit) values ('Townhouse', '0.1');
insert into unit_type (name, students_per_unit) values ('Duplex', '0.1');
insert into unit_type (name, students_per_unit) values ('Attached structure', '0.03');
insert into unit_type (name, students_per_unit) values ('Detached house', '0.2');
insert into unit_type (name, students_per_unit) values ('Detached structure', '0.03');



select bu.id, pop10_pct, students_per_unit, pop10_pct * students_per_unit as s
from bld_unit bu
join (select * from bld_y where buse=1) b on bu.bld = b.objectid
join unit_type ut on b.btype = ut.name
join district_block db on st_within(b.center, db.geom)
order by s desc
limit 10000
;

-- Can't distribute students to units by ratio because too many buildings have the same exact percentages (s above).

create table student
	( id serial primary key
	, unit int not null references bld_unit(id)
	);


create or replace function distribute_students() returns void as $$
declare
	db district_block%rowtype;
	bu_id bigint;
begin
    delete from student;
    for db in select * from district_block order by id
    loop
        raise notice 'id % enrollment %', db.id, db.enrollment;
        continue when db.enrollment is null;
        for s in 1..db.enrollment
        loop
            select bu.id into bu_id
            from bld_unit bu
            join bld_y b on (bu.bld = b.objectid)
            where st_within( b.center, db.geom )
            order by random()
            -- TODO Add weights to building types
            limit 1;
            if not found then
                raise exception 'building unit not found';
            end if;
            insert into student (unit) values (bu_id);
        end loop;
    end loop;
end;
$$ language plpgsql;

select distribute_students();


drop table if exists student_loc;
create table student_loc as
select b.*
from student s
join bld_unit bu on (s.unit = bu.id)
join bld_y b on (bu.bld = b.objectid)
;
insert into geometry_columns
values ('', 'acps_redistricting', 'student_loc', 'center', 2, 4326, 'POINT');


-- Install pgrouting, and run osm2pgrouting for the area

-- Find the nearest ways_vertex for each school.

create table school_vertex as
select school.id as school, school.geom
	, vertex.id, vertex.osm_id, vertex.the_geom
	, st_setsrid( st_makeline( school.geom, vertex.the_geom ), 4326 ) as nearest
from acps_nodes school
cross join lateral
	(
	select *
	from ways_vertices_pgr as v
	order by school.geom <-> v.the_geom asc
	limit 1
	) as vertex
where school.id in
	(356567851,356568426,356568627,356568659,356568820,356568874
	,356569022,356569187,356569300,356581307,356581309,356605115,356605117
	);
alter table school_vertex add constraint check (st_srid(geom) = 4326);

-- Check this with QGIS.  It is correct.

SELECT * FROM pgr_dijkstra
	('select gid as id, source, target, length_m as cost from ways'
	, ARRAY[958,1270,4566,3616,4614,9388,11161,5870,10394,11298,10082,5246,9121]
	, ARRAY[13224, 6963]
	, directed := false
	);
