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



drop table if exists bld_district;
create table bld_district as
select b.objectid as bld, d.id as district
from alexandria.bld_y b
join acps_district d on st_within( b.wkb_geometry, d.geom )
where b.buse = 1
;

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

