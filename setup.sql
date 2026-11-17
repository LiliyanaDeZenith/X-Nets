-- X'Nest: tempel semua di Supabase > SQL Editor, lalu Run (aman dijalankan ulang)
create table if not exists public.profiles(
  id uuid primary key references auth.users on delete cascade,
  username text not null unique check (username ~ '^[a-z0-9_.]{3,20}$'),
  display text, bio text default '', avatar text, banner jsonb,
  verified_until timestamptz, role text not null default 'user',
  banned boolean not null default false,
  s jsonb not null default '{"theme":"auto","size":"n","autoplay":0,"dm":"all"}',
  created_at timestamptz not null default now());
create table if not exists public.strikes(
  user_id uuid primary key references public.profiles on delete cascade, n int not null default 0);
create table if not exists public.posts(
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles on delete cascade,
  body text not null default '', media jsonb, created_at timestamptz not null default now());
create table if not exists public.likes(
  post_id bigint references public.posts on delete cascade,
  user_id uuid references public.profiles on delete cascade, primary key(post_id,user_id));
create table if not exists public.comments(
  id bigint generated always as identity primary key,
  post_id bigint not null references public.posts on delete cascade,
  user_id uuid not null references public.profiles on delete cascade,
  body text not null, created_at timestamptz not null default now());
create table if not exists public.rooms(
  id uuid primary key default gen_random_uuid(),
  type text not null check (type in ('ch','com')), name text not null, descr text default '',
  owner uuid not null references public.profiles on delete cascade,
  created_at timestamptz not null default now());
create table if not exists public.room_members(
  room_id uuid references public.rooms on delete cascade,
  user_id uuid references public.profiles on delete cascade, primary key(room_id,user_id));
create table if not exists public.messages(
  id bigint generated always as identity primary key, room text not null,
  user_id uuid not null references public.profiles on delete cascade, body text not null,
  announce boolean not null default false, created_at timestamptz not null default now());
create index if not exists messages_room on public.messages(room, created_at);
create index if not exists posts_time on public.posts(created_at desc);
create table if not exists public.site(id int primary key, text text, banner jsonb);
create table if not exists public.words(word text primary key check (word ~ '^[a-z0-9]{1,30}$'));
insert into public.site(id,text) values(1,'Selamat datang di X''Nest') on conflict do nothing;
insert into public.words(word) values ('anjing'),('bangsat'),('kontol'),('memek'),('ngentot'),('bajingan'),('goblok'),('tolol'),('babi'),('asu'),('fuck'),('shit'),('bitch'),('asshole') on conflict do nothing;

create or replace function public.is_dev() returns boolean language sql stable security definer set search_path=public as
$$ select exists(select 1 from profiles where id=auth.uid() and role='dev') $$;
create or replace function public.is_banned() returns boolean language sql stable security definer set search_path=public as
$$ select coalesce((select banned from profiles where id=auth.uid()),false) $$;
create or replace function public.username_free(u text) returns boolean language sql stable security definer set search_path=public as
$$ select not exists(select 1 from profiles where username=lower(u)) $$;
create or replace function public.can_read(r text) returns boolean language sql stable security definer set search_path=public as
$$ select auth.uid() is not null and (r='global'
   or (r like 'dm:%' and auth.uid()::text = any(string_to_array(substr(r,4),'~')))
   or exists(select 1 from rooms where id::text=r)) $$;
create or replace function public.can_post(r text) returns boolean language plpgsql stable security definer set search_path=public as $$
declare me uuid := auth.uid(); ids text[]; tp profiles; mp profiles; rm rooms;
begin
  if me is null or is_banned() then return false; end if;
  if r='global' then return true; end if;
  if r like 'dm:%' then
    ids := string_to_array(substr(r,4),'~');
    if array_length(ids,1)<>2 or not (me::text = any(ids)) then return false; end if;
    select * into tp from profiles where id::text = (select x from unnest(ids) x where x<>me::text limit 1);
    if tp.id is null or tp.banned then return false; end if;
    if tp.role<>'dev' and tp.s->>'dm'='verified' then
      select * into mp from profiles where id=me;
      return mp.role='dev' or coalesce(mp.verified_until>now(),false);
    end if;
    return true;
  end if;
  select * into rm from rooms where id::text=r;
  if rm.id is null then return false; end if;
  if rm.type='ch' then return rm.owner=me or is_dev(); end if;
  return exists(select 1 from room_members where room_id=rm.id and user_id=me);
end $$;

create or replace function public.censor(t text) returns text language plpgsql stable set search_path=public as $$
declare p text;
begin
  select string_agg(word,'|') into p from words;
  if p is null or t is null then return t; end if;
  return regexp_replace(t,'\m('||p||')\M','****','gi');
end $$;
create or replace function public.t_clean() returns trigger language plpgsql security definer set search_path=public as $$
declare c text;
begin
  c := censor(new.body);
  if c is distinct from new.body then
    insert into strikes(user_id,n) values(new.user_id,1) on conflict(user_id) do update set n=strikes.n+1;
    new.body := c;
  end if;
  return new;
end $$;
create or replace function public.t_clean2() returns trigger language plpgsql security definer set search_path=public as $$
begin
  if tg_table_name='profiles' then new.display:=censor(new.display); new.bio:=censor(new.bio);
  else new.name:=censor(new.name); new.descr:=censor(new.descr); end if;
  return new;
end $$;
create or replace function public.t_room() returns trigger language plpgsql security definer set search_path=public as $$
begin
  if tg_op='INSERT' then insert into room_members(room_id,user_id) values(new.id,new.owner); return new;
  else delete from messages where room=old.id::text; return old; end if;
end $$;
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
declare u text; dv boolean;
begin
  u := lower(coalesce(new.raw_user_meta_data->>'username',''));
  dv := lower(new.email)='websitescarlett@gmail.com';
  if u !~ '^[a-z0-9_.]{3,20}$' then raise exception 'Username tidak valid'; end if;
  if u in ('devweb','admin') and not dv then raise exception 'Username dipakai'; end if;
  insert into profiles(id,username,display,role) values(new.id,u,u,case when dv then 'dev' else 'user' end);
  return new;
end $$;
do $$ declare t text; begin
  foreach t in array array['posts','comments','messages'] loop
    execute format('drop trigger if exists clean on public.%I',t);
    execute format('create trigger clean before insert on public.%I for each row execute function public.t_clean()',t);
  end loop;
  foreach t in array array['profiles','rooms'] loop
    execute format('drop trigger if exists clean2 on public.%I',t);
    execute format('create trigger clean2 before insert or update on public.%I for each row execute function public.t_clean2()',t);
  end loop;
end $$;
drop trigger if exists room_ins on public.rooms;
create trigger room_ins after insert on public.rooms for each row execute function public.t_room();
drop trigger if exists room_del on public.rooms;
create trigger room_del after delete on public.rooms for each row execute function public.t_room();
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

create or replace function public._purge(uid uuid) returns void language plpgsql security definer set search_path=public as $$
begin
  delete from messages where room in (select id::text from rooms where owner=uid) or (room like 'dm:%' and position(uid::text in room)>0);
  delete from auth.users where id=uid;
end $$;
create or replace function public.delete_me() returns void language plpgsql security definer set search_path=public as $$
begin
  if auth.uid() is null or is_dev() then raise exception 'Tidak diizinkan'; end if;
  perform _purge(auth.uid());
end $$;
create or replace function public.dev_delete(uid uuid) returns void language plpgsql security definer set search_path=public as $$
begin
  if not is_dev() then raise exception 'Khusus developer'; end if;
  if exists(select 1 from profiles where id=uid and role='dev') then raise exception 'Akun developer tidak bisa dihapus'; end if;
  perform _purge(uid);
end $$;
create or replace function public.dev_ban(uid uuid) returns void language plpgsql security definer set search_path=public as $$
declare b boolean;
begin
  if not is_dev() then raise exception 'Khusus developer'; end if;
  update profiles set banned=not banned where id=uid and role<>'dev' returning banned into b;
  if b is not null then update auth.users set banned_until=case when b then 'infinity'::timestamptz else null end where id=uid; end if;
end $$;
create or replace function public.dev_verify(uid uuid, months int) returns void language plpgsql security definer set search_path=public as $$
begin
  if not is_dev() then raise exception 'Khusus developer'; end if;
  update profiles set verified_until=case when months<0 then null
    else greatest(coalesce(verified_until,now()),now()) + months*interval '1 month' end where id=uid;
end $$;
create or replace function public.dev_users() returns table(id uuid, email text, viol int) language sql stable security definer set search_path=public as $$
  select u.id, u.email::text, coalesce(s.n,0) from auth.users u left join strikes s on s.user_id=u.id where is_dev() $$;

create or replace function public._pol(t text, n text, c text, u text, w text) returns void language plpgsql as $$
begin
  execute format('alter table public.%I enable row level security', t);
  execute format('drop policy if exists %I on public.%I', n, t);
  execute format('create policy %I on public.%I for %s to authenticated %s %s', n, t, c,
    case when u is null then '' else 'using ('||u||')' end,
    case when w is null then '' else 'with check ('||w||')' end);
end $$;
select public._pol('profiles','p_sel','select','true',null);
select public._pol('profiles','p_upd','update','id=auth.uid()','id=auth.uid()');
select public._pol('strikes','p_sel','select','public.is_dev()',null);
select public._pol('posts','p_sel','select','true',null);
select public._pol('posts','p_ins','insert',null,'user_id=auth.uid() and not public.is_banned()');
select public._pol('posts','p_del','delete','user_id=auth.uid() or public.is_dev()',null);
select public._pol('likes','p_sel','select','true',null);
select public._pol('likes','p_ins','insert',null,'user_id=auth.uid() and not public.is_banned()');
select public._pol('likes','p_del','delete','user_id=auth.uid()',null);
select public._pol('comments','p_sel','select','true',null);
select public._pol('comments','p_ins','insert',null,'user_id=auth.uid() and not public.is_banned()');
select public._pol('comments','p_del','delete','user_id=auth.uid() or public.is_dev()',null);
select public._pol('rooms','p_sel','select','true',null);
select public._pol('rooms','p_ins','insert',null,'owner=auth.uid() and not public.is_banned()');
select public._pol('rooms','p_del','delete','owner=auth.uid() or public.is_dev()',null);
select public._pol('room_members','p_sel','select','true',null);
select public._pol('room_members','p_ins','insert',null,'user_id=auth.uid() and not public.is_banned()');
select public._pol('room_members','p_del','delete','user_id=auth.uid() and not exists(select 1 from public.rooms r where r.id=room_id and r.owner=auth.uid())',null);
select public._pol('messages','p_sel','select','public.can_read(room)',null);
select public._pol('messages','p_ins','insert',null,'user_id=auth.uid() and public.can_post(room) and (not announce or public.is_dev())');
select public._pol('messages','p_del','delete','public.is_dev() and public.can_read(room)',null);
select public._pol('site','p_sel','select','true',null);
select public._pol('site','p_upd','update','public.is_dev()','public.is_dev()');
select public._pol('words','p_sel','select','true',null);
select public._pol('words','p_ins','insert',null,'public.is_dev()');
select public._pol('words','p_del','delete','public.is_dev()',null);
drop function public._pol(text,text,text,text,text);

grant usage on schema public to anon, authenticated;
grant select,insert,update,delete on all tables in schema public to authenticated;
grant usage,select on all sequences in schema public to authenticated;
grant execute on all functions in schema public to anon, authenticated;
revoke update on public.profiles from authenticated;
revoke insert,delete on public.profiles from authenticated;
grant update(display,bio,avatar,banner,s) on public.profiles to authenticated;
revoke execute on function public._purge(uuid) from public, anon, authenticated;

insert into storage.buckets(id,name,public,file_size_limit) values('media','media',true,null)
  on conflict(id) do update set public=true, file_size_limit=null;
drop policy if exists "media upload" on storage.objects;
create policy "media upload" on storage.objects for insert to authenticated
  with check (bucket_id='media' and (storage.foldername(name))[1]=auth.uid()::text);
do $$ declare t text; begin
  foreach t in array array['messages','posts','likes','comments','rooms','room_members','profiles','site','words'] loop
    if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename=t) then
      execute format('alter publication supabase_realtime add table public.%I',t);
    end if;
  end loop;
end $$;
insert into public.profiles(id,username,display,role)
select id,'user'||substr(replace(id::text,'-',''),1,8),'user'||substr(replace(id::text,'-',''),1,8),
  case when lower(email)='websitescarlett@gmail.com' then 'dev' else 'user' end
from auth.users u where not exists(select 1 from public.profiles p where p.id=u.id);
