-- Tambahan: Mora, beli centang, sandi terlarang (jalankan sekali di SQL Editor, aman diulang)
create table if not exists public.wallets(
  user_id uuid primary key references public.profiles on delete cascade,
  mora int not null default 0, last_claim timestamptz);
create table if not exists public.banned_pw(pw text primary key check (length(pw) between 1 and 100));
create or replace function public.t_wallet() returns trigger language plpgsql security definer set search_path=public as $$
begin insert into wallets(user_id) values(new.id) on conflict do nothing; return new; end $$;
drop trigger if exists wallet_ins on public.profiles;
create trigger wallet_ins after insert on public.profiles for each row execute function public.t_wallet();
insert into public.wallets(user_id) select id from public.profiles on conflict do nothing;

create or replace function public.claim_mora() returns int language plpgsql security definer set search_path=public as $$
declare m int; l timestamptz;
begin
  if auth.uid() is null or is_banned() then raise exception 'Tidak diizinkan'; end if;
  if is_dev() then raise exception 'Developer memiliki Mora tak terbatas'; end if;
  insert into wallets(user_id) values(auth.uid()) on conflict do nothing;
  select last_claim into l from wallets where user_id=auth.uid() for update;
  if l is not null and l > now() - interval '7 days' then
    raise exception 'Klaim berikutnya tersedia pada %', to_char(l + interval '7 days','DD-MM-YYYY HH24:MI'); end if;
  update wallets set mora=mora+100, last_claim=now() where user_id=auth.uid() returning mora into m;
  return m;
end $$;
create or replace function public.buy_check(plan int) returns int language plpgsql security definer set search_path=public as $$
declare cost int; d int; m int;
begin
  if auth.uid() is null or is_banned() then raise exception 'Tidak diizinkan'; end if;
  select c, dd into cost, d from (values (0,100,7),(1,500,30),(2,2500,150),(3,6000,365)) v(i,c,dd) where i=plan;
  if cost is null then raise exception 'Paket tidak valid'; end if;
  if not is_dev() then
    insert into wallets(user_id) values(auth.uid()) on conflict do nothing;
    update wallets set mora=mora-cost where user_id=auth.uid() and mora>=cost returning mora into m;
    if m is null then raise exception 'Mora tidak cukup'; end if;
  end if;
  update profiles set verified_until=greatest(coalesce(verified_until,now()),now())+d*interval '1 day' where id=auth.uid();
  return coalesce(m,0);
end $$;
create or replace function public.pw_allowed(p text) returns boolean language sql stable security definer set search_path=public as
$$ select not exists(select 1 from banned_pw where lower(pw)=lower(p)) $$;
create or replace function public.pw_violation() returns boolean language sql stable security definer set search_path=public,extensions as
$$ select exists(select 1 from auth.users u, banned_pw b where u.id=auth.uid() and u.encrypted_password<>'' and u.encrypted_password=crypt(b.pw,u.encrypted_password)) $$;
create or replace function public.dev_pw_check(uid uuid) returns boolean language sql stable security definer set search_path=public,extensions as
$$ select public.is_dev() and exists(select 1 from auth.users u, banned_pw b where u.id=uid and u.encrypted_password<>'' and u.encrypted_password=crypt(b.pw,u.encrypted_password)) $$;

alter table public.wallets enable row level security;
alter table public.banned_pw enable row level security;
drop policy if exists p_sel on public.wallets;
create policy p_sel on public.wallets for select to authenticated using (user_id=auth.uid() or public.is_dev());
drop policy if exists p_sel on public.banned_pw;
create policy p_sel on public.banned_pw for select to authenticated using (public.is_dev());
drop policy if exists p_ins on public.banned_pw;
create policy p_ins on public.banned_pw for insert to authenticated with check (public.is_dev());
drop policy if exists p_del on public.banned_pw;
create policy p_del on public.banned_pw for delete to authenticated using (public.is_dev());
revoke insert,update,delete on public.wallets from authenticated;
grant select on public.wallets to authenticated;
grant select,insert,delete on public.banned_pw to authenticated;
grant execute on function public.claim_mora(), public.buy_check(int), public.pw_allowed(text), public.pw_violation(), public.dev_pw_check(uuid) to anon, authenticated;
