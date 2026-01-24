// generate-ai-item Edge Function
// AI 生成搜刮物品
// 使用阿里云百炼 qwen-flash 模型生成独特的物品名称和背景故事

import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// 系统提示词
const SYSTEM_PROMPT = `你是一个末日生存游戏的物品生成器。游戏背景是丧尸末日后的世界。

根据搜刮地点生成物品列表，每个物品包含：
- name: 独特名称（15字以内），可以暗示前主人身份或物品来历
- category: 分类（医疗/食物/工具/武器/材料）
- rarity: 稀有度（common/uncommon/rare/epic/legendary）
- story: 背景故事（50-100字），要有画面感，营造末日氛围

规则：
1. 物品类型要与地点相关（医院出医疗物品，超市出食物等）
2. 名称要有创意，带有末日特色
3. 故事要简短有画面感，可以有黑色幽默，但不要太血腥
4. 稀有度越高，名称越独特，故事越精彩

只返回 JSON 数组，不要其他内容。格式如下：
[{"name":"物品名","category":"分类","rarity":"稀有度","story":"故事"}]`;

// 根据危险值生成稀有度分布
function getRarityWeights(dangerLevel: number): Record<string, number> {
    switch (dangerLevel) {
        case 1:
        case 2:
            return { common: 70, uncommon: 25, rare: 5, epic: 0, legendary: 0 };
        case 3:
            return { common: 50, uncommon: 30, rare: 15, epic: 5, legendary: 0 };
        case 4:
            return { common: 0, uncommon: 40, rare: 35, epic: 20, legendary: 5 };
        case 5:
            return { common: 0, uncommon: 0, rare: 30, epic: 40, legendary: 30 };
        default:
            return { common: 60, uncommon: 30, rare: 10, epic: 0, legendary: 0 };
    }
}

// 根据 POI 类型获取主要物品分类
function getCategoryHint(poiType: string): string {
    const categoryMap: Record<string, string> = {
        hospital: "医疗物品为主（绷带、药品、急救包等）",
        pharmacy: "医疗物品为主（药品、维生素、急救用品等）",
        store: "食物和日用品为主（罐头、饮料、零食等）",
        supermarket: "食物和日用品为主（罐头、饮料、零食等）",
        convenience_store: "食物和饮料为主（零食、饮料、香烟等）",
        gasStation: "工具和燃料为主（汽油、工具、零食等）",
        restaurant: "食物为主（剩余食材、调料、厨具等）",
        cafe: "食物和饮料为主（咖啡、茶、甜点等）",
    };
    return categoryMap[poiType] || "各类物资";
}

Deno.serve(async (req: Request) => {
    // 处理 CORS 预检请求
    if (req.method === "OPTIONS") {
        return new Response("ok", { headers: corsHeaders });
    }

    try {
        // 验证请求方法
        if (req.method !== "POST") {
            return new Response(
                JSON.stringify({ success: false, error: "Method not allowed" }),
                { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        // 解析请求
        const { poi, itemCount = 3 } = await req.json();

        if (!poi || !poi.name || !poi.type) {
            return new Response(
                JSON.stringify({ success: false, error: "Missing required poi information" }),
                { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        const dangerLevel = poi.dangerLevel || 2;
        const rarityWeights = getRarityWeights(dangerLevel);
        const categoryHint = getCategoryHint(poi.type);

        // 构建用户提示词
        const userPrompt = `搜刮地点：${poi.name}
地点类型：${poi.type}
危险等级：${dangerLevel}/5
物品倾向：${categoryHint}

请生成 ${itemCount} 个物品。

稀有度分布参考（按概率）：
- 普通(common): ${rarityWeights.common}%
- 优秀(uncommon): ${rarityWeights.uncommon}%
- 稀有(rare): ${rarityWeights.rare}%
- 史诗(epic): ${rarityWeights.epic}%
- 传奇(legendary): ${rarityWeights.legendary}%

返回 JSON 数组格式，只返回数组，不要其他内容。`;

        console.log(`[generate-ai-item] Generating ${itemCount} items for: ${poi.name} (danger: ${dangerLevel})`);

        // 获取 API Key
        const apiKey = Deno.env.get("DASHSCOPE_API_KEY");
        if (!apiKey) {
            console.error("[generate-ai-item] DASHSCOPE_API_KEY not configured");
            return new Response(
                JSON.stringify({ success: false, error: "AI service not configured" }),
                { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        // 调用阿里云百炼 API（国际版端点）
        const response = await fetch("https://dashscope-intl.aliyuncs.com/compatible-mode/v1/chat/completions", {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                "Authorization": `Bearer ${apiKey}`,
            },
            body: JSON.stringify({
                model: "qwen-turbo",
                messages: [
                    { role: "system", content: SYSTEM_PROMPT },
                    { role: "user", content: userPrompt }
                ],
                max_tokens: 1000,
                temperature: 0.8,
            }),
        });

        if (!response.ok) {
            const errorText = await response.text();
            console.error(`[generate-ai-item] AI API error: ${response.status} - ${errorText}`);
            return new Response(
                JSON.stringify({ success: false, error: "AI service error", details: errorText }),
                { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        const aiResponse = await response.json();
        const content = aiResponse.choices?.[0]?.message?.content;

        if (!content) {
            console.error("[generate-ai-item] Empty AI response");
            return new Response(
                JSON.stringify({ success: false, error: "Empty AI response" }),
                { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        console.log(`[generate-ai-item] AI response: ${content.substring(0, 200)}...`);

        // 解析 AI 返回的 JSON
        let items;
        try {
            // 尝试直接解析
            items = JSON.parse(content);
        } catch {
            // 如果失败，尝试提取 JSON 数组
            const jsonMatch = content.match(/\[[\s\S]*\]/);
            if (jsonMatch) {
                items = JSON.parse(jsonMatch[0]);
            } else {
                throw new Error("Cannot parse AI response as JSON");
            }
        }

        // 验证并规范化物品数据
        const validatedItems = (items as Array<Record<string, string>>).map((item: Record<string, string>) => ({
            name: String(item.name || "神秘物品").substring(0, 20),
            category: String(item.category || "材料"),
            rarity: ["common", "uncommon", "rare", "epic", "legendary"].includes(item.rarity)
                ? item.rarity
                : "common",
            story: String(item.story || "这个物品的来历无人知晓...").substring(0, 200),
        }));

        console.log(`[generate-ai-item] Successfully generated ${validatedItems.length} items`);

        return new Response(
            JSON.stringify({ success: true, items: validatedItems }),
            { headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );

    } catch (error) {
        console.error("[generate-ai-item] Error:", error);
        return new Response(
            JSON.stringify({ success: false, error: "Internal server error", details: String(error) }),
            { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
    }
});
