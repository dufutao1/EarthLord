// Supabase Edge Function: Accept Trade
// 处理交易接受的原子性操作（调用 PostgreSQL 存储过程）

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 1. 获取请求参数
    const { offer_id } = await req.json()

    if (!offer_id) {
      throw new Error('缺少 offer_id 参数')
    }

    // 2. 初始化 Supabase 客户端
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: req.headers.get('Authorization')! },
        },
      }
    )

    // 3. 获取当前用户
    const { data: { user }, error: userError } = await supabaseClient.auth.getUser()

    if (userError || !user) {
      throw new Error('未登录或认证失败')
    }

    const buyerId = user.id
    const buyerUsername = user.email || '未知用户'

    console.log(`[Accept Trade] 用户 ${buyerId} 尝试接受挂单 ${offer_id}`)

    // 4. 调用 PostgreSQL 存储过程（带行级锁和事务）
    const { data, error } = await supabaseClient.rpc('accept_trade_offer', {
      p_offer_id: offer_id,
      p_buyer_id: buyerId,
      p_buyer_username: buyerUsername
    })

    if (error) {
      console.error('[Accept Trade] RPC 调用失败:', error)
      throw new Error(error.message)
    }

    // 5. 检查存储过程返回结果
    const result = data as { success: boolean; message?: string; error?: string }

    if (!result.success) {
      console.error('[Accept Trade] 交易失败:', result.error)
      return new Response(
        JSON.stringify({
          success: false,
          error: result.error
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 400,
        }
      )
    }

    console.log('[Accept Trade] 交易成功完成')

    return new Response(
      JSON.stringify({
        success: true,
        message: result.message || '交易成功'
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )
  } catch (error) {
    console.error('[Accept Trade] 错误:', error)

    return new Response(
      JSON.stringify({
        success: false,
        error: error.message
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      }
    )
  }
})
