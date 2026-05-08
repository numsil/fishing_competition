--
-- PostgreSQL database dump
--

\restrict ipxDOtIUwN783AeAHoSed9ye3zsEMMecdIWIOshaFZaVgLBgzABXYFmIeMlD9Ig

-- Dumped from database version 17.6
-- Dumped by pg_dump version 18.3

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA public;


--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: calc_post_score(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.calc_post_score() RETURNS trigger
    LANGUAGE plpgsql
    AS $$                                                                                                                                   
  BEGIN                
    NEW.score := CASE
      WHEN NEW.length IS NULL OR NEW.length < 30 THEN 0
      WHEN NEW.length >= 60 THEN ROUND(POW(NEW.length, 2.5) / 800 * 10)
      WHEN NEW.length >= 55 THEN ROUND(POW(NEW.length, 2.5) / 800 * 7)                                                                            
      WHEN NEW.length >= 50 THEN ROUND(POW(NEW.length, 2.5) / 800 * 5)                                                                            
      WHEN NEW.length >= 45 THEN ROUND(POW(NEW.length, 2.5) / 800 * 3)                                                                            
      WHEN NEW.length >= 40 THEN ROUND(POW(NEW.length, 2.5) / 800 * 2)                                                                            
      ELSE                       ROUND(POW(NEW.length, 2.5) / 800 * 1.5)
    END;                                                                                                                                          
    RETURN NEW;        
  END;                                                                                                                                            
  $$;


--
-- Name: enforce_initial_review_status(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_initial_review_status() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.is_personal_record = true THEN
    NEW.review_status := 'pending';
  ELSE
    NEW.review_status := 'approved';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: enforce_posts_update_columns(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_posts_update_columns() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$                                                                                                                                   
    DECLARE                                                                        
      is_owner      BOOLEAN := (auth.uid() = OLD.user_id);                                                                                        
      is_privileged BOOLEAN;                                                       
    BEGIN                                                                                                                                         
      -- DB 슈퍼유저 또는 service_role은 통과 (백필/관리 작업용)                   
      IF current_user IN ('postgres', 'supabase_admin')                                                                                           
         OR auth.role() = 'service_role' THEN
        RETURN NEW;                                                                                                                               
      END IF;                                                                      
                                         
      IF is_owner THEN                                                                                                                            
        IF NEW.review_status IS DISTINCT FROM OLD.review_status THEN
          SELECT (role = 'admin' OR is_verifier = true)                                                                                           
          INTO is_privileged                                                                                                                      
          FROM users WHERE id = auth.uid();
                                                                                                                                                  
          IF NOT COALESCE(is_privileged, false) THEN                               
            RAISE EXCEPTION 'Post owner cannot change review_status (USE_VERIFICATION_FLOW)';                                                     
          END IF;                        
        END IF;                                                                                                                                   
        RETURN NEW;                                                                
      END IF;                                                                                                                                     
                                         
      -- 비-소유자: review_status만 변경 허용                                                                                                     
      IF NEW.user_id            IS DISTINCT FROM OLD.user_id            THEN RAISE EXCEPTION 'Cannot change user_id'; END IF;
      IF NEW.league_id          IS DISTINCT FROM OLD.league_id          THEN RAISE EXCEPTION 'Cannot change league_id'; END IF;
      IF NEW.image_url          IS DISTINCT FROM OLD.image_url          THEN RAISE EXCEPTION 'Only post owner can change image_url'; END IF;      
      IF NEW.image_urls         IS DISTINCT FROM OLD.image_urls         THEN RAISE EXCEPTION 'Only post owner can change image_urls'; END IF;
      IF NEW.video_url          IS DISTINCT FROM OLD.video_url          THEN RAISE EXCEPTION 'Only post owner can change video_url'; END IF;      
      IF NEW.caption            IS DISTINCT FROM OLD.caption            THEN RAISE EXCEPTION 'Only post owner can change caption'; END IF;
      IF NEW.location           IS DISTINCT FROM OLD.location           THEN RAISE EXCEPTION 'Only post owner can change location'; END IF;       
      IF NEW.lat                IS DISTINCT FROM OLD.lat                THEN RAISE EXCEPTION 'Only post owner can change lat'; END IF;
      IF NEW.lng                IS DISTINCT FROM OLD.lng                THEN RAISE EXCEPTION 'Only post owner can change lng'; END IF;            
      IF NEW.fish_type          IS DISTINCT FROM OLD.fish_type          THEN RAISE EXCEPTION 'Only post owner can change fish_type'; END IF;      
      IF NEW.lure_type          IS DISTINCT FROM OLD.lure_type          THEN RAISE EXCEPTION 'Only post owner can change lure_type'; END IF;      
      IF NEW.length             IS DISTINCT FROM OLD.length             THEN RAISE EXCEPTION 'Only post owner can change length'; END IF;         
      IF NEW.weight             IS DISTINCT FROM OLD.weight             THEN RAISE EXCEPTION 'Only post owner can change weight'; END IF;         
      IF NEW.catch_count        IS DISTINCT FROM OLD.catch_count        THEN RAISE EXCEPTION 'Only post owner can change catch_count'; END IF;    
      IF NEW.is_lunker          IS DISTINCT FROM OLD.is_lunker          THEN RAISE EXCEPTION 'Only post owner can change is_lunker'; END IF;      
      IF NEW.is_personal_record IS DISTINCT FROM OLD.is_personal_record THEN RAISE EXCEPTION 'Cannot change is_personal_record'; END IF;          
      IF NEW.score              IS DISTINCT FROM OLD.score              THEN RAISE EXCEPTION 'Only post owner can change score'; END IF;          
      IF NEW.aspect_ratio       IS DISTINCT FROM OLD.aspect_ratio       THEN RAISE EXCEPTION 'Only post owner can change aspect_ratio'; END IF;   
                                                                                                                                                  
      RETURN NEW;                                                                                                                                 
    END;                                                                                                                                          
    $$;


--
-- Name: get_league_ranking(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_league_ranking(p_league_id uuid) RETURNS TABLE(user_id uuid, username text, avatar_url text, best_length numeric, total_length numeric, total_count integer, total_score integer, best_score integer, fish_type text, is_lunker boolean)
    LANGUAGE plpgsql STABLE
    AS $$                                                                                                                                           
  DECLARE                       
    v_rule text;                                                                                                                                  
    v_limit int;                                                                   
  BEGIN                             
    SELECT COALESCE(l.rule, '최대어'), COALESCE(l.catch_limit, 1)
    INTO v_rule, v_limit                                                                                                                          
    FROM leagues l WHERE l.id = p_league_id;
                                                                                                                                                  
    IF v_rule IS NULL THEN                                                         
      RETURN;                       
    END IF;                          
                                                                                                                                                  
    RETURN QUERY                    
    WITH user_posts AS (                                                                                                                          
      SELECT                                                                                                                                      
        p.user_id AS uid,                
        p.score AS sc,                                                                                                                            
        CASE WHEN v_rule = '무게' THEN p.weight ELSE p.length END AS measure,      
        p.fish_type AS ft,               
        p.is_lunker AS lunker_flag  
      FROM posts p                       
      WHERE p.league_id = p_league_id                                                                                                             
        AND p.review_status = 'approved'
        AND COALESCE(p.is_deleted, false) = false                                                                                                 
    ),                                                                                                                                            
    user_aggregates AS (        
      SELECT                                                                                                                                      
        up.uid,                                                                    
        MAX(up.measure) AS max_measure,                                                                                                           
        COUNT(*)::int AS cnt,                                                      
        COALESCE(MAX(up.sc), 0)::int AS max_score,                                                                                                
        bool_or(COALESCE(up.lunker_flag, false)) AS lunker
      FROM user_posts up                                                                                                                          
      GROUP BY up.uid                                                              
    ),                              
    top_measures AS (                
      SELECT                                                                                                                                      
        uids.uid,                   
        COALESCE(SUM(t.m), 0) AS sum_top_measure                                                                                                  
      FROM (SELECT DISTINCT uid FROM user_posts) uids                                                                                             
      LEFT JOIN LATERAL (       
        SELECT up.measure AS m                                                                                                                    
        FROM user_posts up                                                         
        WHERE up.uid = uids.uid AND up.measure IS NOT NULL
        ORDER BY up.measure DESC     
        LIMIT v_limit                                                                                                                             
      ) t ON true                   
      GROUP BY uids.uid                                                                                                                           
    ),                                                                                                                                            
    top_scores AS (                 
      SELECT                                                                                                                                      
        uids.uid,                                                                                                                                 
        COALESCE(SUM(t.s), 0)::int AS sum_top_score
      FROM (SELECT DISTINCT uid FROM user_posts) uids                                                                                             
      LEFT JOIN LATERAL (                                                          
        SELECT up.sc AS s                
        FROM user_posts up          
        WHERE up.uid = uids.uid      
        ORDER BY up.sc DESC                                                                                                                       
        LIMIT v_limit                    
      ) t ON true                                                                                                                                 
      GROUP BY uids.uid                                                                                                                           
    ),                                
    user_fish AS (                                                                                                                                
      SELECT DISTINCT ON (up.uid) up.uid, up.ft AS chosen_ft                       
      FROM user_posts up                                                                                                                          
      ORDER BY up.uid, up.ft    
    )                                                                                                                                             
    SELECT                                                                         
      p.user_id,                     
      u.username,                     
      u.avatar_url,                                                                                                                               
      ua.max_measure,
      COALESCE(tm.sum_top_measure, 0::numeric),                                                                                                   
      COALESCE(ua.cnt, 0),                                                         
      CASE                                                                                                                                        
        WHEN v_rule = '마릿수' THEN COALESCE(ua.cnt, 0) * 10                       
        ELSE COALESCE(ts.sum_top_score, 0)
      END,                          
      COALESCE(ua.max_score, 0),     
      COALESCE(uf.chosen_ft, '배스'),                                                                                                             
      COALESCE(ua.lunker, false)         
    FROM league_participants p                                                                                                                    
    JOIN users u ON u.id = p.user_id                                                                                                              
    LEFT JOIN user_aggregates ua ON ua.uid = p.user_id
    LEFT JOIN top_measures tm ON tm.uid = p.user_id                                                                                               
    LEFT JOIN top_scores ts ON ts.uid = p.user_id                                  
    LEFT JOIN user_fish uf ON uf.uid = p.user_id                                                                                                  
    WHERE p.league_id = p_league_id   
    ORDER BY                                                                                                                                      
      CASE                                                                         
        WHEN v_rule = '마릿수' THEN COALESCE(ua.cnt, 0) * 10                                                                                      
        ELSE COALESCE(ts.sum_top_score, 0)
      END DESC,                                                                                                                                   
      COALESCE(ua.cnt, 0) DESC,                                                    
      COALESCE(ua.max_score, 0) DESC;                                                                                                             
  END;                                                                             
  $$;


--
-- Name: get_league_score_ranking(integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_league_score_ranking(top_n integer DEFAULT 10, season_year integer DEFAULT NULL::integer) RETURNS TABLE(user_id uuid, username text, avatar_url text, score integer)
    LANGUAGE sql STABLE
    AS $$                                                                            
    WITH season AS (                                                                                                                              
      SELECT                             
        (COALESCE(season_year, EXTRACT(YEAR FROM NOW())::int)::text || '-01-01')::timestamp AS s,                                                 
        ((COALESCE(season_year, EXTRACT(YEAR FROM NOW())::int) + 1)::text || '-01-01')::timestamp AS e
    ),                                                  
    catch_scores AS (                                   
      SELECT p.user_id AS uid, COALESCE(SUM(p.score), 0)::int AS s
      FROM posts p, season                                                                                                                        
      WHERE p.league_id IS NOT NULL                     
        AND p.review_status = 'approved'                                                                                                          
        AND COALESCE(p.is_deleted, false) = false                                  
        AND p.created_at >= season.s                                                                                                              
        AND p.created_at < season.e                                                                                                               
      GROUP BY p.user_id                                                                                                                          
    ),                                                                                                                                            
    bonus_scores AS (                                                                                                                             
      SELECT lp.user_id AS uid, COALESCE(SUM(lp.rank_bonus), 0)::int AS s                                                                         
      FROM league_participants lp, season                                                                                                         
      WHERE lp.rank_bonus > 0                                                      
        AND lp.rank_bonus_earned_at >= season.s                                                                                                   
        AND lp.rank_bonus_earned_at < season.e                                     
      GROUP BY lp.user_id                                                                                                                         
    ),                                                                             
    combined AS (                        
      SELECT uid, SUM(s)::int AS total                                                                                                            
      FROM (                                                                                                                                      
        SELECT uid, s FROM catch_scores                                                                                                           
        UNION ALL                                                                                                                                 
        SELECT uid, s FROM bonus_scores                                            
      ) sub                                                                                                                                       
      GROUP BY uid                                                                 
    )                                                                                                                                             
    SELECT u.id, u.username, u.avatar_url, c.total                                 
    FROM combined c                                                                                                                               
    JOIN users u ON u.id = c.uid       
    WHERE c.total > 0                                                                                                                             
    ORDER BY c.total DESC                                                          
    LIMIT top_n;                         
  $$;


--
-- Name: get_personal_score_ranking(integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_personal_score_ranking(top_n integer DEFAULT 10, season_year integer DEFAULT NULL::integer) RETURNS TABLE(user_id uuid, username text, avatar_url text, score integer)
    LANGUAGE sql STABLE
    AS $$                                                                                                                                           
    WITH season AS (                                    
      SELECT                                                                                                                                      
        (COALESCE(season_year, EXTRACT(YEAR FROM NOW())::int)::text || '-01-01')::timestamp AS s,
        ((COALESCE(season_year, EXTRACT(YEAR FROM NOW())::int) + 1)::text || '-01-01')::timestamp AS e
    ),                                                  
    user_scores AS (                                    
      SELECT p.user_id AS uid, COALESCE(SUM(p.score), 0)::int AS total
      FROM posts p, season                                                                                                                        
      WHERE p.is_personal_record = true  
        AND p.review_status = 'approved'                                                                                                          
        AND COALESCE(p.is_deleted, false) = false                                  
        AND p.created_at >= season.s                                                                                                              
        AND p.created_at < season.e                                                                                                               
      GROUP BY p.user_id                                                                                                                          
    )                                                                                                                                             
    SELECT u.id, u.username, u.avatar_url, us.total                                
    FROM user_scores us                                                                                                                           
    JOIN users u ON u.id = us.uid                       
    WHERE us.total > 0                                                                                                                            
    ORDER BY us.total DESC                                                                                                                        
    LIMIT top_n;                         
  $$;


--
-- Name: get_user_league_stats(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_user_league_stats(p_user_id uuid) RETURNS TABLE(participation_count integer, win_count integer)
    LANGUAGE sql STABLE
    AS $$                                                                            
    WITH my_leagues AS (                                                                                                                          
      SELECT lp.league_id, l.rule, COALESCE(l.catch_limit, 1) AS catch_limit       
      FROM league_participants lp                                                                                                                 
      JOIN leagues l ON l.id = lp.league_id                                                                                                       
      WHERE lp.user_id = p_user_id AND l.status = 'completed'
    ),                                                                                                                                            
    scored AS (                                                                    
      SELECT             
        ml.league_id,
        ml.rule,                                                                                                                                  
        ml.catch_limit,         
        league_user_score(ml.league_id, p_user_id, ml.rule, ml.catch_limit) AS my_score                                                           
      FROM my_leagues ml                                                                                                                          
    ),                          
    ranks AS (                                                                                                                                    
      SELECT                                                                       
        s.league_id, 
        (SELECT COUNT(*) FROM league_participants lp                                                                                              
         WHERE lp.league_id = s.league_id
           AND lp.user_id != p_user_id                                                                                                            
           AND league_user_score(s.league_id, lp.user_id, s.rule, s.catch_limit) > s.my_score                                                     
        ) AS higher_count                 
      FROM scored s                                                                                                                               
    )                                                                              
    SELECT                             
      (SELECT COUNT(*)::int FROM my_leagues),
      (SELECT COUNT(*)::int FROM ranks WHERE higher_count = 0);
  $$;


--
-- Name: get_user_profile_summary(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_user_profile_summary(p_user_id uuid) RETURNS jsonb
    LANGUAGE plpgsql STABLE
    AS $$                                                                                                                                 
    DECLARE                                                                                                                                       
      v_season_start timestamp := (EXTRACT(YEAR FROM NOW())::int::text || '-01-01')::timestamp;
      v_season_end   timestamp := ((EXTRACT(YEAR FROM NOW())::int + 1)::text || '-01-01')::timestamp;                                             
      v_user record;                                                                                                                              
      v_catch_score int;                                                                                                                          
      v_bonus_score int;                                                                                                                          
      v_angler_score int;                                                                                                                         
      v_max_fish record;
      v_stats record;                                                                                                                             
    BEGIN                                                   
      SELECT id, email, username, user_key, avatar_url, manner_temperature, is_lunker_club                                                        
      INTO v_user                                                                                                                                 
      FROM users WHERE id = p_user_id;
      IF NOT FOUND THEN RETURN NULL; END IF;                                                                                                      
                                                            
      -- 진행중/완료 리그 조과만 점수 합산                                                                                                        
      SELECT COALESCE(SUM(p.score), 0)::int INTO v_catch_score
      FROM posts p                                                                                                                                
      JOIN leagues l ON l.id = p.league_id                  
      WHERE p.user_id = p_user_id                                                                                                                 
        AND p.review_status = 'approved' AND COALESCE(p.is_deleted, false) = false
        AND p.created_at >= v_season_start AND p.created_at < v_season_end                                                                        
        AND l.status IN ('in_progress', 'completed');
                                                                                                                                                  
      SELECT COALESCE(SUM(rank_bonus), 0)::int INTO v_bonus_score                                                                                 
      FROM league_participants
      WHERE user_id = p_user_id AND rank_bonus > 0                                                                                                
        AND rank_bonus_earned_at >= v_season_start AND rank_bonus_earned_at < v_season_end;                                                       
                                                                                                                                                  
      SELECT COALESCE(SUM(score), 0)::int INTO v_angler_score                                                                                     
      FROM posts                                                                                                                                  
      WHERE user_id = p_user_id AND is_personal_record = true
        AND review_status = 'approved' AND COALESCE(is_deleted, false) = false                                                                    
        AND created_at >= v_season_start AND created_at < v_season_end;
                                                                                                                                                  
      SELECT p.id, p.image_url, p.fish_type, p.length, p.location, p.created_at                                                                   
      INTO v_max_fish                                                                                                                             
      FROM posts p                                                                                                                                
      LEFT JOIN leagues l ON l.id = p.league_id             
      WHERE p.user_id = p_user_id AND p.review_status = 'approved'
        AND COALESCE(p.is_deleted, false) = false AND p.length IS NOT NULL                                                                        
        AND (p.league_id IS NULL OR l.status IN ('in_progress', 'completed'))                                                                     
      ORDER BY p.length DESC LIMIT 1;                                                                                                             
                                                                                                                                                  
      SELECT * INTO v_stats FROM get_user_league_stats(p_user_id);
                                                                                                                                                  
      RETURN jsonb_build_object(                                                                                                                  
        'id', v_user.id,
        'email', v_user.email,                                                                                                                    
        'username', v_user.username,                        
        'user_key', v_user.user_key,
        'avatar_url', v_user.avatar_url,
        'manner_temperature', v_user.manner_temperature,                                                                                          
        'is_lunker_club', COALESCE(v_user.is_lunker_club, false),
        'league_score', v_catch_score + v_bonus_score,                                                                                            
        'angler_score', v_angler_score,                                                                                                           
        'participation_count', COALESCE(v_stats.participation_count, 0),
        'win_count', COALESCE(v_stats.win_count, 0),                                                                                              
        'max_fish', CASE                                    
          WHEN v_max_fish.id IS NULL THEN NULL                                                                                                    
          ELSE jsonb_build_object(                          
            'id', v_max_fish.id,                                                                                                                  
            'image_url', v_max_fish.image_url,              
            'fish_type', v_max_fish.fish_type,                                                                                                    
            'length', v_max_fish.length,
            'location', v_max_fish.location,                                                                                                      
            'created_at', v_max_fish.created_at             
          )                                                                                                                                       
        END
      );                                                                                                                                          
    END;                                                    
  $$;


--
-- Name: get_user_season_stats(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_user_season_stats(p_user_id uuid) RETURNS TABLE(best_rank integer, max_fish_length numeric, total_fish_count integer)
    LANGUAGE sql STABLE
    AS $$
      WITH season AS (
        SELECT
          (EXTRACT(YEAR FROM NOW())::int::text || '-01-01')::timestamp AS s,
          ((EXTRACT(YEAR FROM NOW())::int + 1)::text || '-01-01')::timestamp AS e                                                                 
      ),
      max_fish AS (                                                                                                                               
        SELECT MAX(p.length) AS m                           
        FROM posts p                                                                                                                              
        JOIN leagues l ON l.id = p.league_id, season
        WHERE p.user_id = p_user_id                                                                                                               
          AND p.review_status = 'approved'                  
          AND COALESCE(p.is_deleted, false) = false
          AND p.length IS NOT NULL                                                                                                                
          AND p.created_at >= season.s
          AND p.created_at < season.e                                                                                                             
          AND l.status IN ('in_progress', 'completed')      
      ),
      total_fish AS (
        SELECT COUNT(*)::int AS cnt                                                                                                               
        FROM posts p
        JOIN leagues l ON l.id = p.league_id, season                                                                                              
        WHERE p.user_id = p_user_id                         
          AND p.review_status = 'approved'
          AND COALESCE(p.is_deleted, false) = false                                                                                               
          AND p.created_at >= season.s
          AND p.created_at < season.e                                                                                                             
          AND l.status IN ('in_progress', 'completed')      
      ),
      my_leagues AS (
        SELECT lp.league_id, l.rule, COALESCE(l.catch_limit, 1) AS catch_limit                                                                    
        FROM league_participants lp
        JOIN leagues l ON l.id = lp.league_id, season                                                                                             
        WHERE lp.user_id = p_user_id                        
          AND l.start_time >= season.s                                                                                                            
          AND l.start_time < season.e
          AND l.status != 'canceled'                                                                                                              
      ),                                                    
      ranks AS (
        SELECT
          ml.league_id,
          league_user_score(ml.league_id, p_user_id, ml.rule, ml.catch_limit) AS my_score,                                                        
          ml.rule,
          ml.catch_limit                                                                                                                          
        FROM my_leagues ml                                  
      ),
      rank_values AS (
        SELECT                                                                                                                                    
          r.league_id,
          (SELECT COUNT(*) FROM league_participants lp                                                                                            
           WHERE lp.league_id = r.league_id                 
             AND lp.user_id != p_user_id
             AND league_user_score(r.league_id, lp.user_id, r.rule, r.catch_limit) > r.my_score
          ) + 1 AS rk                                                                                                                             
        FROM ranks r
      )                                                                                                                                           
      SELECT                                                
        (SELECT MIN(rk)::int FROM rank_values) AS best_rank,
        (SELECT m FROM max_fish) AS max_fish_length,                                                                                              
        (SELECT cnt FROM total_fish) AS total_fish_count;
  $$;


--
-- Name: hide_conversation(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.hide_conversation(p_conv_id uuid, p_user_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  UPDATE conversations SET
    user1_hidden_at = CASE WHEN user1_id = p_user_id THEN NOW() ELSE user1_hidden_at END,
    user2_hidden_at = CASE WHEN user2_id = p_user_id THEN NOW() ELSE user2_hidden_at END
  WHERE id = p_conv_id;
END;
$$;


--
-- Name: league_user_score(uuid, uuid, text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.league_user_score(p_league_id uuid, p_user_id uuid, p_rule text, p_limit integer) RETURNS numeric
    LANGUAGE plpgsql STABLE
    AS $$                  
  DECLARE                                                                                                                                         
    v numeric;                                                                     
  BEGIN          
    IF p_rule = '마릿수' THEN
      SELECT COUNT(*)::numeric INTO v                                                                                                             
      FROM posts                
      WHERE league_id = p_league_id AND user_id = p_user_id                                                                                       
        AND review_status = 'approved'                                             
        AND COALESCE(is_deleted, false) = false;
    ELSIF p_rule = '무게' THEN         
      SELECT COALESCE(SUM(weight), 0) INTO v FROM (
        SELECT weight FROM posts          
        WHERE league_id = p_league_id AND user_id = p_user_id                                                                                     
          AND review_status = 'approved'
          AND COALESCE(is_deleted, false) = false                                                                                                 
          AND weight IS NOT NULL                                                                                                                  
        ORDER BY weight DESC LIMIT p_limit
      ) t;                                                                                                                                        
    ELSE                                                                           
      SELECT COALESCE(SUM(length), 0) INTO v FROM (                                                                                               
        SELECT length FROM posts
        WHERE league_id = p_league_id AND user_id = p_user_id                                                                                     
          AND review_status = 'approved'                                                                                                          
          AND COALESCE(is_deleted, false) = false
          AND length IS NOT NULL                                                                                                                  
        ORDER BY length DESC LIMIT p_limit                                                                                                        
      ) t;                                
    END IF;                                                                                                                                       
    RETURN COALESCE(v, 0);                                                         
  END;                   
  $$;


--
-- Name: on_dm_read(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.on_dm_read(p_conv_id uuid, p_reader_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  UPDATE conversations SET
    unread_count_user1 = CASE WHEN user1_id = p_reader_id THEN 0 ELSE unread_count_user1 END,
    unread_count_user2 = CASE WHEN user2_id = p_reader_id THEN 0 ELSE unread_count_user2 END
  WHERE id = p_conv_id;
END;
$$;


--
-- Name: on_dm_sent(uuid, uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.on_dm_sent(p_conv_id uuid, p_sender_id uuid, p_content text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  UPDATE conversations SET
    last_message       = p_content,
    last_message_at    = NOW(),
    unread_count_user1 = CASE WHEN user2_id = p_sender_id THEN unread_count_user1 + 1 ELSE unread_count_user1 END,
    unread_count_user2 = CASE WHEN user1_id = p_sender_id THEN unread_count_user2 + 1 ELSE unread_count_user2 END,
    user1_hidden_at    = CASE WHEN user2_id = p_sender_id THEN NULL ELSE user1_hidden_at END,
    user2_hidden_at    = CASE WHEN user1_id = p_sender_id THEN NULL ELSE user2_hidden_at END
  WHERE id = p_conv_id;
END;
$$;


--
-- Name: prevent_owner_review_status_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.prevent_owner_review_status_change() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$                                                                                                                           
  DECLARE
    v_is_privileged BOOLEAN;                                                                                                                      
  BEGIN                                                     
    IF OLD.review_status IS NOT DISTINCT FROM NEW.review_status THEN
      RETURN NEW;                                                                                                                                 
    END IF;
                                                                                                                                                  
    -- 포스트 주인이 아니면 통과                                                                                                                  
    IF auth.uid() IS DISTINCT FROM NEW.user_id THEN
      RETURN NEW;                                                                                                                                 
    END IF;                                                 
                                                                                                                                                  
    -- 주인이지만 admin 또는 verifier이면 허용
    SELECT (role = 'admin' OR is_verifier = true)                                                                                                 
    INTO v_is_privileged                                                                                                                          
    FROM users WHERE id = auth.uid();
                                                                                                                                                  
    IF COALESCE(v_is_privileged, false) THEN                
      RETURN NEW;                                                                                                                                 
    END IF;                                                 

    RAISE EXCEPTION 'Post owner cannot change review_status (USE_VERIFICATION_FLOW)';                                                             
  END;
  $$;


--
-- Name: save_league_rank_bonuses(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.save_league_rank_bonuses(p_league_id uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$                                                                                                                                           
  DECLARE                                                                                                                                         
    v_count int;                         
    v_base int;                                                                                                                                   
    v_now timestamptz := NOW();                                                                                                                   
  BEGIN                                                                                                                                           
    SELECT COUNT(*)::int INTO v_count                                                                                                             
    FROM league_participants                                                       
    WHERE league_id = p_league_id;  
                                     
    IF v_count = 0 THEN RETURN; END IF;                                                                                                           
                                    
    v_base := CASE                                                                                                                                
      WHEN v_count <= 6 THEN 10                                                                                                                   
      WHEN v_count <= 12 THEN 24    
      WHEN v_count <= 19 THEN 40                                                                                                                  
      ELSE 60                                                                                                                                     
    END;                             
                                                                                                                                                  
    WITH ranks AS (                      
      SELECT                    
        r.user_id,                                                                                                                                
        ROW_NUMBER() OVER (           
          ORDER BY r.total_score DESC, r.total_count DESC, r.best_score DESC                                                                      
        ) AS rk                          
      FROM get_league_ranking(p_league_id) r                                                                                                      
    ),                                   
    bonuses AS (                                                                                                                                  
      SELECT                             
        r.user_id,                    
        ROUND(v_count * v_base * CASE                                                                                                             
          WHEN r.rk = 1 THEN 1.00        
          WHEN r.rk = 2 THEN 0.60                                                                                                                 
          WHEN r.rk = 3 THEN 0.40        
          WHEN r.rk <= 5 THEN 0.20                                                                                                                
          WHEN r.rk <= 10 THEN 0.10      
          ELSE 0.05                   
        END)::int AS bonus                                                                                                                        
      FROM ranks r                    
    )                                                                                                                                             
    UPDATE league_participants lp        
    SET rank_bonus = b.bonus,                                                                                                                     
        rank_bonus_earned_at = v_now     
    FROM bonuses b                                                                                                                                
    WHERE lp.league_id = p_league_id     
      AND lp.user_id = b.user_id                                                                                                                  
      AND b.bonus > 0;                
  END;                                                                                                                                            
  $$;


--
-- Name: user_is_assigned_voter(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.user_is_assigned_voter(p_verification_id uuid, p_user_id uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$
  SELECT EXISTS (
    SELECT 1 FROM verification_votes
    WHERE verification_id = p_verification_id
      AND voter_id = p_user_id
  );
$$;


--
-- Name: validate_rank_bonus_update(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.validate_rank_bonus_update() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_n    INT;
  v_base INT;
  v_max  INT;
BEGIN
  -- 값이 바뀌지 않거나 0으로 리셋할 때는 통과
  IF NEW.rank_bonus = OLD.rank_bonus OR NEW.rank_bonus = 0 THEN
    RETURN NEW;
  END IF;

  -- 리그 승인 참가자 수 조회
  SELECT COUNT(*) INTO v_n
  FROM league_participants
  WHERE league_id = NEW.league_id
    AND status = 'approved';

  v_base := CASE
    WHEN v_n <= 6  THEN 10
    WHEN v_n <= 12 THEN 24
    WHEN v_n <= 19 THEN 40
    ELSE 60
  END;

  -- 최대 허용값 = n * base * 1.0 (rank 1, multiplier 100%)
  v_max := CEIL(v_n::NUMERIC * v_base * 1.0);

  IF NEW.rank_bonus > v_max THEN
    RAISE EXCEPTION
      'rank_bonus % exceeds allowed maximum % (participants=%, base=%)',
      NEW.rank_bonus, v_max, v_n, v_base;
  END IF;

  RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: app_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.app_versions (
    env text NOT NULL,
    version text NOT NULL,
    build_number integer NOT NULL,
    apk_url text,
    ios_url text,
    release_notes text,
    force_update boolean DEFAULT false,
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: badges; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.badges (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    name text NOT NULL,
    description text,
    icon_url text,
    condition text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);


--
-- Name: catch_verifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.catch_verifications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    post_id uuid NOT NULL,
    submitter_id uuid NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    approve_count integer DEFAULT 0 NOT NULL,
    reject_count integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    resolved_at timestamp with time zone
);


--
-- Name: conversations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.conversations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user1_id uuid NOT NULL,
    user2_id uuid NOT NULL,
    last_message text,
    last_message_at timestamp with time zone DEFAULT now() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    unread_count_user1 integer DEFAULT 0 NOT NULL,
    unread_count_user2 integer DEFAULT 0 NOT NULL,
    user1_hidden_at timestamp with time zone,
    user2_hidden_at timestamp with time zone,
    CONSTRAINT conversations_ordered_pair CHECK ((user1_id < user2_id))
);


--
-- Name: league_participants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.league_participants (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    league_id uuid NOT NULL,
    user_id uuid NOT NULL,
    status text DEFAULT 'pending'::text,
    has_paid boolean DEFAULT false,
    joined_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    rank_bonus integer DEFAULT 0 NOT NULL,
    rank_bonus_earned_at timestamp with time zone,
    CONSTRAINT league_participants_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text])))
);


--
-- Name: leagues; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.leagues (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    host_id uuid NOT NULL,
    title text NOT NULL,
    description text,
    location text NOT NULL,
    lat numeric,
    lng numeric,
    start_time timestamp with time zone NOT NULL,
    end_time timestamp with time zone NOT NULL,
    entry_fee integer DEFAULT 0,
    max_participants integer DEFAULT 100,
    status text DEFAULT 'recruiting'::text,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    fish_types text DEFAULT '배스'::text,
    rule text DEFAULT '최대어'::text,
    prize_info text,
    is_public boolean DEFAULT true,
    catch_limit integer DEFAULT 1,
    intro_image_urls text[] DEFAULT '{}'::text[] NOT NULL,
    short_description text,
    allow_gallery boolean DEFAULT true NOT NULL,
    CONSTRAINT leagues_status_check CHECK ((status = ANY (ARRAY['recruiting'::text, 'in_progress'::text, 'completed'::text, 'canceled'::text])))
);


--
-- Name: messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.messages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    conversation_id uuid NOT NULL,
    sender_id uuid NOT NULL,
    content text NOT NULL,
    is_read boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: post_comments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_comments (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    post_id uuid NOT NULL,
    user_id uuid NOT NULL,
    content text NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);


--
-- Name: post_likes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_likes (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    post_id uuid NOT NULL,
    user_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);


--
-- Name: posts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.posts (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    user_id uuid NOT NULL,
    league_id uuid,
    image_url text NOT NULL,
    caption text,
    fish_type text DEFAULT '배스'::text,
    length numeric,
    lure_type text,
    depth numeric,
    temperature numeric,
    location text,
    lat numeric,
    lng numeric,
    is_lunker boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    weight numeric,
    catch_count integer DEFAULT 1,
    is_personal_record boolean DEFAULT false NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    video_url text,
    image_urls text[],
    aspect_ratio double precision,
    score integer DEFAULT 0 NOT NULL,
    review_status text DEFAULT 'pending'::text NOT NULL,
    CONSTRAINT chk_posts_length CHECK (((length IS NULL) OR ((length > (0)::numeric) AND (length <= (200)::numeric)))),
    CONSTRAINT posts_review_status_check CHECK ((review_status = ANY (ARRAY['approved'::text, 'held'::text, 'pending'::text, 'rejected'::text])))
);


--
-- Name: reports; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reports (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    post_id uuid,
    reporter_id uuid NOT NULL,
    reason text NOT NULL,
    status text DEFAULT 'pending'::text,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT reports_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'resolved'::text, 'rejected'::text])))
);


--
-- Name: score_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.score_logs (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    user_id uuid NOT NULL,
    change numeric NOT NULL,
    reason text NOT NULL,
    admin_id uuid,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);


--
-- Name: tickets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tickets (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    user_id uuid NOT NULL,
    title text NOT NULL,
    message text NOT NULL,
    status text DEFAULT 'open'::text,
    admin_reply text,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT tickets_status_check CHECK ((status = ANY (ARRAY['open'::text, 'in_progress'::text, 'closed'::text])))
);


--
-- Name: user_badges; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_badges (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    user_id uuid NOT NULL,
    badge_id uuid NOT NULL,
    assigned_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid NOT NULL,
    email text NOT NULL,
    username text NOT NULL,
    avatar_url text,
    manner_temperature numeric DEFAULT 36.5,
    is_lunker_club boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    status text DEFAULT 'active'::text,
    role text DEFAULT 'user'::text,
    is_deleted boolean DEFAULT false NOT NULL,
    is_verifier boolean DEFAULT false NOT NULL,
    user_key text NOT NULL,
    CONSTRAINT users_role_check CHECK ((role = ANY (ARRAY['user'::text, 'admin'::text]))),
    CONSTRAINT users_status_check CHECK ((status = ANY (ARRAY['active'::text, 'banned'::text])))
);


--
-- Name: verification_votes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.verification_votes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    verification_id uuid NOT NULL,
    voter_id uuid NOT NULL,
    vote text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    voted_at timestamp with time zone,
    CONSTRAINT verification_votes_vote_check CHECK (((vote IS NULL) OR (vote = ANY (ARRAY['approve'::text, 'reject'::text]))))
);


--
-- Name: app_versions app_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_versions
    ADD CONSTRAINT app_versions_pkey PRIMARY KEY (env);


--
-- Name: badges badges_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.badges
    ADD CONSTRAINT badges_pkey PRIMARY KEY (id);


--
-- Name: catch_verifications catch_verifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.catch_verifications
    ADD CONSTRAINT catch_verifications_pkey PRIMARY KEY (id);


--
-- Name: catch_verifications catch_verifications_post_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.catch_verifications
    ADD CONSTRAINT catch_verifications_post_id_key UNIQUE (post_id);


--
-- Name: conversations conversations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT conversations_pkey PRIMARY KEY (id);


--
-- Name: conversations conversations_unique_pair; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT conversations_unique_pair UNIQUE (user1_id, user2_id);


--
-- Name: league_participants league_participants_league_id_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.league_participants
    ADD CONSTRAINT league_participants_league_id_user_id_key UNIQUE (league_id, user_id);


--
-- Name: league_participants league_participants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.league_participants
    ADD CONSTRAINT league_participants_pkey PRIMARY KEY (id);


--
-- Name: leagues leagues_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leagues
    ADD CONSTRAINT leagues_pkey PRIMARY KEY (id);


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id);


--
-- Name: post_comments post_comments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_comments
    ADD CONSTRAINT post_comments_pkey PRIMARY KEY (id);


--
-- Name: post_likes post_likes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_likes
    ADD CONSTRAINT post_likes_pkey PRIMARY KEY (id);


--
-- Name: post_likes post_likes_post_id_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_likes
    ADD CONSTRAINT post_likes_post_id_user_id_key UNIQUE (post_id, user_id);


--
-- Name: posts posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT posts_pkey PRIMARY KEY (id);


--
-- Name: reports reports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reports
    ADD CONSTRAINT reports_pkey PRIMARY KEY (id);


--
-- Name: score_logs score_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.score_logs
    ADD CONSTRAINT score_logs_pkey PRIMARY KEY (id);


--
-- Name: tickets tickets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tickets
    ADD CONSTRAINT tickets_pkey PRIMARY KEY (id);


--
-- Name: user_badges user_badges_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_badges
    ADD CONSTRAINT user_badges_pkey PRIMARY KEY (id);


--
-- Name: user_badges user_badges_user_id_badge_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_badges
    ADD CONSTRAINT user_badges_user_id_badge_id_key UNIQUE (user_id, badge_id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users users_user_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_user_key_key UNIQUE (user_key);


--
-- Name: verification_votes verification_votes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.verification_votes
    ADD CONSTRAINT verification_votes_pkey PRIMARY KEY (id);


--
-- Name: verification_votes verification_votes_verification_id_voter_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.verification_votes
    ADD CONSTRAINT verification_votes_verification_id_voter_id_key UNIQUE (verification_id, voter_id);


--
-- Name: conversations_user1_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX conversations_user1_idx ON public.conversations USING btree (user1_id);


--
-- Name: conversations_user2_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX conversations_user2_idx ON public.conversations USING btree (user2_id);


--
-- Name: idx_catch_verif_post; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_catch_verif_post ON public.catch_verifications USING btree (post_id);


--
-- Name: idx_catch_verif_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_catch_verif_status ON public.catch_verifications USING btree (status);


--
-- Name: idx_lp_rank_bonus_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lp_rank_bonus_user ON public.league_participants USING btree (user_id, rank_bonus_earned_at) WHERE (rank_bonus > 0);


--
-- Name: idx_posts_league_review; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_posts_league_review ON public.posts USING btree (league_id, review_status, score DESC) WHERE (league_id IS NOT NULL);


--
-- Name: idx_posts_league_score; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_posts_league_score ON public.posts USING btree (league_id, score DESC) WHERE (is_deleted = false);


--
-- Name: idx_posts_personal_record; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_posts_personal_record ON public.posts USING btree (user_id, is_personal_record) WHERE (league_id IS NULL);


--
-- Name: idx_users_is_verifier; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_is_verifier ON public.users USING btree (is_verifier) WHERE (is_verifier = true);


--
-- Name: idx_verif_votes_verif; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_verif_votes_verif ON public.verification_votes USING btree (verification_id);


--
-- Name: idx_verif_votes_voter; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_verif_votes_voter ON public.verification_votes USING btree (voter_id) WHERE (vote IS NULL);


--
-- Name: messages_conversation_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_conversation_id_idx ON public.messages USING btree (conversation_id, created_at);


--
-- Name: posts posts_enforce_initial_review_status; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER posts_enforce_initial_review_status BEFORE INSERT ON public.posts FOR EACH ROW EXECUTE FUNCTION public.enforce_initial_review_status();


--
-- Name: posts posts_enforce_update_columns; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER posts_enforce_update_columns BEFORE UPDATE ON public.posts FOR EACH ROW EXECUTE FUNCTION public.enforce_posts_update_columns();


--
-- Name: posts trg_calc_post_score; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_calc_post_score BEFORE INSERT OR UPDATE OF length ON public.posts FOR EACH ROW EXECUTE FUNCTION public.calc_post_score();


--
-- Name: league_participants trg_validate_rank_bonus; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_validate_rank_bonus BEFORE UPDATE OF rank_bonus ON public.league_participants FOR EACH ROW EXECUTE FUNCTION public.validate_rank_bonus_update();


--
-- Name: catch_verifications catch_verifications_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.catch_verifications
    ADD CONSTRAINT catch_verifications_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: catch_verifications catch_verifications_submitter_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.catch_verifications
    ADD CONSTRAINT catch_verifications_submitter_id_fkey FOREIGN KEY (submitter_id) REFERENCES public.users(id);


--
-- Name: conversations conversations_user1_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT conversations_user1_id_fkey FOREIGN KEY (user1_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: conversations conversations_user2_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT conversations_user2_id_fkey FOREIGN KEY (user2_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: league_participants league_participants_league_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.league_participants
    ADD CONSTRAINT league_participants_league_id_fkey FOREIGN KEY (league_id) REFERENCES public.leagues(id) ON DELETE CASCADE;


--
-- Name: league_participants league_participants_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.league_participants
    ADD CONSTRAINT league_participants_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: leagues leagues_host_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leagues
    ADD CONSTRAINT leagues_host_id_fkey FOREIGN KEY (host_id) REFERENCES public.users(id);


--
-- Name: messages messages_conversation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES public.conversations(id) ON DELETE CASCADE;


--
-- Name: messages messages_sender_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: post_comments post_comments_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_comments
    ADD CONSTRAINT post_comments_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: post_comments post_comments_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_comments
    ADD CONSTRAINT post_comments_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: post_likes post_likes_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_likes
    ADD CONSTRAINT post_likes_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: post_likes post_likes_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_likes
    ADD CONSTRAINT post_likes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: posts posts_league_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT posts_league_id_fkey FOREIGN KEY (league_id) REFERENCES public.leagues(id) ON DELETE SET NULL;


--
-- Name: posts posts_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT posts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: reports reports_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reports
    ADD CONSTRAINT reports_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: reports reports_reporter_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reports
    ADD CONSTRAINT reports_reporter_id_fkey FOREIGN KEY (reporter_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: score_logs score_logs_admin_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.score_logs
    ADD CONSTRAINT score_logs_admin_id_fkey FOREIGN KEY (admin_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: score_logs score_logs_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.score_logs
    ADD CONSTRAINT score_logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: tickets tickets_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tickets
    ADD CONSTRAINT tickets_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_badges user_badges_badge_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_badges
    ADD CONSTRAINT user_badges_badge_id_fkey FOREIGN KEY (badge_id) REFERENCES public.badges(id) ON DELETE CASCADE;


--
-- Name: user_badges user_badges_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_badges
    ADD CONSTRAINT user_badges_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: users users_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id);


--
-- Name: verification_votes verification_votes_verification_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.verification_votes
    ADD CONSTRAINT verification_votes_verification_id_fkey FOREIGN KEY (verification_id) REFERENCES public.catch_verifications(id) ON DELETE CASCADE;


--
-- Name: verification_votes verification_votes_voter_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.verification_votes
    ADD CONSTRAINT verification_votes_voter_id_fkey FOREIGN KEY (voter_id) REFERENCES public.users(id);


--
-- Name: post_comments Authenticated users can comment.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Authenticated users can comment." ON public.post_comments FOR INSERT WITH CHECK ((auth.role() = 'authenticated'::text));


--
-- Name: leagues Authenticated users can create leagues.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Authenticated users can create leagues." ON public.leagues FOR INSERT WITH CHECK ((auth.role() = 'authenticated'::text));


--
-- Name: posts Authenticated users can create posts.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Authenticated users can create posts." ON public.posts FOR INSERT WITH CHECK (((auth.uid() = user_id) AND ((league_id IS NULL) OR (EXISTS ( SELECT 1
   FROM public.league_participants
  WHERE ((league_participants.league_id = posts.league_id) AND (league_participants.user_id = auth.uid()) AND (league_participants.status = 'approved'::text)))))));


--
-- Name: league_participants Authenticated users can join leagues.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Authenticated users can join leagues." ON public.league_participants FOR INSERT WITH CHECK ((auth.role() = 'authenticated'::text));


--
-- Name: post_likes Authenticated users can toggle likes.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Authenticated users can toggle likes." ON public.post_likes FOR INSERT WITH CHECK ((auth.role() = 'authenticated'::text));


--
-- Name: badges Badges are viewable by everyone.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Badges are viewable by everyone." ON public.badges FOR SELECT USING ((is_active = true));


--
-- Name: post_comments Comments are viewable by everyone.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Comments are viewable by everyone." ON public.post_comments FOR SELECT USING (true);


--
-- Name: leagues League hosts can delete their leagues.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "League hosts can delete their leagues." ON public.leagues FOR DELETE USING ((auth.uid() = host_id));


--
-- Name: league_participants League hosts can update participants.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "League hosts can update participants." ON public.league_participants FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM public.leagues
  WHERE ((leagues.id = league_participants.league_id) AND (leagues.host_id = auth.uid())))));


--
-- Name: leagues League hosts can update their leagues.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "League hosts can update their leagues." ON public.leagues FOR UPDATE USING ((auth.uid() = host_id));


--
-- Name: leagues Leagues are viewable by everyone.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Leagues are viewable by everyone." ON public.leagues FOR SELECT USING (true);


--
-- Name: post_likes Likes are viewable by everyone.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Likes are viewable by everyone." ON public.post_likes FOR SELECT USING (true);


--
-- Name: league_participants Participants viewable by everyone.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Participants viewable by everyone." ON public.league_participants FOR SELECT USING (true);


--
-- Name: posts Posts are viewable by everyone.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Posts are viewable by everyone." ON public.posts FOR SELECT USING (true);


--
-- Name: users Public profiles are viewable by everyone.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public profiles are viewable by everyone." ON public.users FOR SELECT USING (true);


--
-- Name: user_badges User badges are viewable by everyone.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "User badges are viewable by everyone." ON public.user_badges FOR SELECT USING (true);


--
-- Name: reports Users can create reports.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can create reports." ON public.reports FOR INSERT WITH CHECK ((auth.role() = 'authenticated'::text));


--
-- Name: tickets Users can create tickets.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can create tickets." ON public.tickets FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: post_comments Users can delete own comments.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can delete own comments." ON public.post_comments FOR DELETE USING ((auth.uid() = user_id));


--
-- Name: post_likes Users can delete own likes.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can delete own likes." ON public.post_likes FOR DELETE USING ((auth.uid() = user_id));


--
-- Name: posts Users can delete own posts.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can delete own posts." ON public.posts FOR DELETE USING ((auth.uid() = user_id));


--
-- Name: users Users can insert their own profile.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can insert their own profile." ON public.users FOR INSERT WITH CHECK ((auth.uid() = id));


--
-- Name: league_participants Users can leave or hosts can remove participants.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can leave or hosts can remove participants." ON public.league_participants FOR DELETE USING (((auth.uid() = user_id) OR (EXISTS ( SELECT 1
   FROM public.leagues
  WHERE ((leagues.id = league_participants.league_id) AND (leagues.host_id = auth.uid()))))));


--
-- Name: posts Users can update own posts; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can update own posts" ON public.posts FOR UPDATE USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: posts Users can update own posts.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can update own posts." ON public.posts FOR UPDATE USING ((auth.uid() = user_id));


--
-- Name: users Users can update own profile.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can update own profile." ON public.users FOR UPDATE USING ((auth.uid() = id));


--
-- Name: reports Users can view own reports.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can view own reports." ON public.reports FOR SELECT USING ((auth.uid() = reporter_id));


--
-- Name: tickets Users can view own tickets.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can view own tickets." ON public.tickets FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: posts admin can update review_status; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "admin can update review_status" ON public.posts FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM public.users u
  WHERE ((u.id = auth.uid()) AND (u.role = 'admin'::text))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.users u
  WHERE ((u.id = auth.uid()) AND (u.role = 'admin'::text)))));


--
-- Name: app_versions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.app_versions ENABLE ROW LEVEL SECURITY;

--
-- Name: app_versions app_versions_public_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY app_versions_public_read ON public.app_versions FOR SELECT USING (true);


--
-- Name: badges; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.badges ENABLE ROW LEVEL SECURITY;

--
-- Name: catch_verifications; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.catch_verifications ENABLE ROW LEVEL SECURITY;

--
-- Name: conversations; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;

--
-- Name: posts league host can update review_status; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "league host can update review_status" ON public.posts FOR UPDATE USING (((league_id IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM public.leagues
  WHERE ((leagues.id = posts.league_id) AND (leagues.host_id = auth.uid())))))) WITH CHECK (true);


--
-- Name: league_participants; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.league_participants ENABLE ROW LEVEL SECURITY;

--
-- Name: leagues; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.leagues ENABLE ROW LEVEL SECURITY;

--
-- Name: messages; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

--
-- Name: post_comments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.post_comments ENABLE ROW LEVEL SECURITY;

--
-- Name: post_likes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.post_likes ENABLE ROW LEVEL SECURITY;

--
-- Name: posts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;

--
-- Name: reports; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

--
-- Name: score_logs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.score_logs ENABLE ROW LEVEL SECURITY;

--
-- Name: tickets; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.tickets ENABLE ROW LEVEL SECURITY;

--
-- Name: user_badges; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_badges ENABLE ROW LEVEL SECURITY;

--
-- Name: users; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

--
-- Name: catch_verifications verif_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY verif_insert ON public.catch_verifications FOR INSERT WITH CHECK ((submitter_id = auth.uid()));


--
-- Name: catch_verifications verif_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY verif_select ON public.catch_verifications FOR SELECT USING (((submitter_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM public.users u
  WHERE ((u.id = auth.uid()) AND (u.role = 'admin'::text)))) OR public.user_is_assigned_voter(id, auth.uid())));


--
-- Name: catch_verifications verif_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY verif_update ON public.catch_verifications FOR UPDATE USING (((EXISTS ( SELECT 1
   FROM public.verification_votes v
  WHERE ((v.verification_id = v.id) AND (v.voter_id = auth.uid())))) OR (EXISTS ( SELECT 1
   FROM public.users u
  WHERE ((u.id = auth.uid()) AND (u.role = 'admin'::text)))))) WITH CHECK (((EXISTS ( SELECT 1
   FROM public.verification_votes v
  WHERE ((v.verification_id = v.id) AND (v.voter_id = auth.uid())))) OR (EXISTS ( SELECT 1
   FROM public.users u
  WHERE ((u.id = auth.uid()) AND (u.role = 'admin'::text))))));


--
-- Name: verification_votes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.verification_votes ENABLE ROW LEVEL SECURITY;

--
-- Name: posts verifier can update review_status; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "verifier can update review_status" ON public.posts FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM public.users u
  WHERE ((u.id = auth.uid()) AND (u.is_verifier = true))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.users u
  WHERE ((u.id = auth.uid()) AND (u.is_verifier = true)))));


--
-- Name: verification_votes vote_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY vote_insert ON public.verification_votes FOR INSERT WITH CHECK (((voter_id <> auth.uid()) AND (EXISTS ( SELECT 1
   FROM public.catch_verifications cv
  WHERE ((cv.id = verification_votes.verification_id) AND (cv.status = 'pending'::text) AND (cv.submitter_id = auth.uid()))))));


--
-- Name: verification_votes vote_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY vote_select ON public.verification_votes FOR SELECT USING (((voter_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM public.users u
  WHERE ((u.id = auth.uid()) AND ((u.is_verifier = true) OR (u.role = 'admin'::text)))))));


--
-- Name: verification_votes vote_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY vote_update ON public.verification_votes FOR UPDATE USING ((voter_id = auth.uid())) WITH CHECK (((voter_id = auth.uid()) AND (EXISTS ( SELECT 1
   FROM public.users u
  WHERE ((u.id = auth.uid()) AND (u.is_verifier = true))))));


--
-- Name: conversations 대화 생성; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "대화 생성" ON public.conversations FOR INSERT WITH CHECK (((auth.uid() = user1_id) OR (auth.uid() = user2_id)));


--
-- Name: messages 메시지 전송; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "메시지 전송" ON public.messages FOR INSERT WITH CHECK (((auth.uid() = sender_id) AND (EXISTS ( SELECT 1
   FROM public.conversations
  WHERE ((conversations.id = messages.conversation_id) AND ((conversations.user1_id = auth.uid()) OR (conversations.user2_id = auth.uid())))))));


--
-- Name: messages 읽음 처리; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "읽음 처리" ON public.messages FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM public.conversations
  WHERE ((conversations.id = messages.conversation_id) AND ((conversations.user1_id = auth.uid()) OR (conversations.user2_id = auth.uid()))))));


--
-- Name: messages 자신의 대화 메시지 조회; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "자신의 대화 메시지 조회" ON public.messages FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public.conversations
  WHERE ((conversations.id = messages.conversation_id) AND ((conversations.user1_id = auth.uid()) OR (conversations.user2_id = auth.uid()))))));


--
-- Name: conversations 자신의 대화 업데이트; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "자신의 대화 업데이트" ON public.conversations FOR UPDATE USING (((auth.uid() = user1_id) OR (auth.uid() = user2_id)));


--
-- Name: conversations 자신의 대화 조회; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "자신의 대화 조회" ON public.conversations FOR SELECT USING (((auth.uid() = user1_id) OR (auth.uid() = user2_id)));


--
-- PostgreSQL database dump complete
--

\unrestrict ipxDOtIUwN783AeAHoSed9ye3zsEMMecdIWIOshaFZaVgLBgzABXYFmIeMlD9Ig

