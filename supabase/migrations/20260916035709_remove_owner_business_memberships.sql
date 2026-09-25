delete from public.business_members as member
using public.profiles as profile
where profile.id = member.profile_id
  and profile.role = 'OWNER';
