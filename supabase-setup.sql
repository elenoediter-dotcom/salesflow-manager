-- ============================================================
--  SalesFlow - Supabase セットアップSQL
--  Supabase Dashboard → SQL Editor に貼り付けて実行してください
-- ============================================================

-- ① プロフィールテーブル（ユーザー設定・営業方法・業種）
CREATE TABLE IF NOT EXISTS public.profiles (
  id              UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name            TEXT    DEFAULT 'マイユーザー',
  avatar          TEXT    DEFAULT '',
  target_sales    INT     DEFAULT 50,
  target_contracts INT    DEFAULT 5,
  animation       BOOLEAN DEFAULT TRUE,
  notify_enabled  BOOLEAN DEFAULT TRUE,
  methods         TEXT[]  DEFAULT ARRAY['SNS DM','メール営業','電話営業','紹介','クラウドソーシング','ポートフォリオ','YouTube'],
  industries      TEXT[]  DEFAULT ARRAY['YouTube / 動画','EC / 通販','不動産','美容・サロン','飲食','IT / SaaS','教育','エンタメ','医療・クリニック','その他'],
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "own_profile" ON public.profiles FOR ALL USING (auth.uid() = id);

-- ② 営業テーブル
CREATE TABLE IF NOT EXISTS public.sales (
  id          TEXT PRIMARY KEY,
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  date        TEXT,
  client      TEXT,
  method      TEXT,
  status      TEXT,
  apo         INT  DEFAULT 0,
  has_order   INT  DEFAULT 0,
  has_contract INT DEFAULT 0,
  amount      NUMERIC,
  memo        TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.sales ENABLE ROW LEVEL SECURITY;
CREATE POLICY "own_sales" ON public.sales FOR ALL USING (auth.uid() = user_id);

-- ③ クライアントテーブル
CREATE TABLE IF NOT EXISTS public.clients (
  id          TEXT PRIMARY KEY,
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  contact     TEXT,
  email       TEXT,
  phone       TEXT,
  industry    TEXT,
  status      TEXT DEFAULT '見込み',
  sns         TEXT,
  budget      TEXT,
  memo        TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
CREATE POLICY "own_clients" ON public.clients FOR ALL USING (auth.uid() = user_id);

-- ④ スケジュールテーブル
CREATE TABLE IF NOT EXISTS public.schedules (
  id         TEXT PRIMARY KEY,
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title      TEXT NOT NULL,
  date       TEXT,
  time       TEXT,
  type       TEXT DEFAULT 'other',
  client     TEXT,
  memo       TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.schedules ENABLE ROW LEVEL SECURITY;
CREATE POLICY "own_schedules" ON public.schedules FOR ALL USING (auth.uid() = user_id);

-- ⑤ 請求書テーブル
CREATE TABLE IF NOT EXISTS public.invoices (
  id          TEXT PRIMARY KEY,
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  number      TEXT,
  client      TEXT,
  issue_date  TEXT,
  due_date    TEXT,
  status      TEXT    DEFAULT '未送付',
  tax_rate    INT     DEFAULT 10,
  memo        TEXT,
  items       JSONB   DEFAULT '[]'::jsonb,
  subtotal    NUMERIC DEFAULT 0,
  tax_amount  NUMERIC DEFAULT 0,
  total       NUMERIC DEFAULT 0,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
CREATE POLICY "own_invoices" ON public.invoices FOR ALL USING (auth.uid() = user_id);

-- ⑥ アクティビティテーブル
CREATE TABLE IF NOT EXISTS public.activities (
  id         BIGSERIAL PRIMARY KEY,
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  text       TEXT,
  color      TEXT,
  icon       TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.activities ENABLE ROW LEVEL SECURITY;
CREATE POLICY "own_activities" ON public.activities FOR ALL USING (auth.uid() = user_id);

-- ⑦ 新規ユーザー登録時にプロフィールを自動作成するトリガー
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.profiles (id, name)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'name', 'マイユーザー')
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
