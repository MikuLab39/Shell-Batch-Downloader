#!/bin/bash

# ================= 配置区 =================
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# 全局变量：用于 Ctrl+C 跳过逻辑
SKIP_CURRENT=0

# ================= 函数定义 =================

# 1. 中断处理
function handle_interrupt() {
    echo -e "\n${RED}>>> [指令] 跳过当前文件！Cleaning up... <<<${NC}"
    SKIP_CURRENT=1
    pkill -P $$ wget 2>/dev/null
}

# 2. 清理 URL
clean_url() { echo "$1" | tr -d '\n\r' | sed 's/%0A//g' | xargs; }

# 3. 字节转 MB
bytes_to_mb() { 
    if [ -z "$1" ] || [ "$1" -eq 0 ]; then echo "未知"; else 
    echo | awk -v size="$1" '{printf "%.2f MB", size/1024/1024}'; fi 
}

# 4. 精准获取文件大小
get_remote_size() {
    local url="$1"
    local output
    output=$(timeout 8 wget --spider --server-response -U "Mozilla/5.0" "$url" 2>&1)
    echo "$output" | grep -i "Content-Length" | tail -n 1 | awk '{print $2}' | tr -d '\r'
}

# ================= 主程序 =================

echo -e "${BLUE}=========================================${NC}"
echo -e "${CYAN}    全能下载助手 v11.0 (通用版)    ${NC}"
echo -e "${BLUE}=========================================${NC}"
echo "1. 【单文件】 快速下载"
echo "2. 【文件夹】 智能抓取 (默认抓取所有文件)"
echo "3. 【列表单】 批量下载 (读取 list.txt)"
echo -e "${BLUE}=========================================${NC}"
read -p "请选择模式 [1]: " MODE
MODE=${MODE:-1}

# ================= 模式 1: 单文件 =================
if [ "$MODE" == "1" ]; then
    echo ""
    read -p "请粘贴文件链接: " RAW_URL
    URL=$(clean_url "$RAW_URL")
    read -p "保存文件名: " FILENAME
    if [ -z "$FILENAME" ]; then echo -e "${RED}文件名不能为空${NC}"; exit 1; fi
    wget -c -U "Mozilla/5.0" -O "$FILENAME" "$URL"
    if [ $? -eq 0 ]; then echo -e "${GREEN}下载成功！${NC}"; else echo -e "${RED}下载失败。${NC}"; fi
    exit 0
fi

# ================= 模式 2 & 3: 批量处理 =================

TEMP_LINKS="raw_links_temp.txt"
> "$TEMP_LINKS"

# --- 阶段 A: 获取链接 ---
if [ "$MODE" == "2" ]; then
    echo -e "${YELLOW}请输入目录链接 (以 / 结尾):${NC}"
    read -r RAW_URL
    BASE_URL=$(clean_url "$RAW_URL")
    if [[ "$BASE_URL" != */ ]]; then BASE_URL="${BASE_URL}/"; fi

    # >>> 修改点：默认下载所有 <<<
    echo -e "${YELLOW}输入文件后缀 (例如 mp3，${GREEN}直接回车代表下载所有文件${YELLOW}):${NC}"
    read -p "> " EXT
    
    # >>> 新增：过滤设置 <<<
    echo -e "${YELLOW}请输入要屏蔽/过滤的关键词 (支持正则)${NC}"
    echo -e "例如输入: ${RED}docker|backup|index${NC} (留空则不过滤)"
    read -p "> " EXCLUDE_KEY

    echo -e "${BLUE}正在分析网页...${NC}"
    wget -q -O index.tmp -U "Mozilla/5.0" "$BASE_URL"
    
    # 核心抓取逻辑更新
    if [ -z "$EXT" ]; then
        # 如果后缀为空，抓取所有 href，但排除 ? (排序参数) 和 / (子文件夹)
        # 这样只下载文件，不下载文件夹和垃圾链接
        grep -oE "href=[\"'][^\"']+[\"']" index.tmp | sed "s/href=[\"']//;s/[\"']$//" | grep -vE "\?|/\$" > raw_links.tmp
        echo -e "${CYAN}已选择：所有文件${NC}"
    else
        # 如果指定后缀
        grep -oE "href=[\"'][^\"']*${EXT}[\"']" index.tmp | sed "s/href=[\"']//;s/[\"']$//" > raw_links.tmp
        echo -e "${CYAN}已选择后缀：$EXT${NC}"
    fi

    # 应用关键词过滤
    if [ ! -z "$EXCLUDE_KEY" ]; then
        echo -e "${CYAN}正在应用过滤规则: 排除 '$EXCLUDE_KEY'${NC}"
        # 使用临时文件进行过滤
        mv raw_links.tmp pre_filter.tmp
        grep -vE "$EXCLUDE_KEY" pre_filter.tmp > raw_links.tmp
        rm pre_filter.tmp
    fi

    # 拼接 URL
    while read -r link; do
        # 排除掉上级目录 ../ 和空行
        if [[ "$link" == "../" ]] || [ -z "$link" ]; then continue; fi
        
        if [[ "$link" == http* ]]; then echo "$link" >> "$TEMP_LINKS"
        else echo "${BASE_URL}${link}" >> "$TEMP_LINKS"
        fi
    done < raw_links.tmp
    rm index.tmp raw_links.tmp

elif [ "$MODE" == "3" ]; then
    if [ ! -f "url_list.txt" ]; then echo -e "${RED}未找到 url_list.txt${NC}"; exit 1; fi
    
    echo -e "${YELLOW}需要过滤列表中的关键词吗? (如 docker|backup)${NC}"
    read -p "> " EXCLUDE_KEY
    
    if [ -z "$EXCLUDE_KEY" ]; then
        cp "url_list.txt" "$TEMP_LINKS"
    else
        grep -vE "$EXCLUDE_KEY" "url_list.txt" > "$TEMP_LINKS"
        echo -e "${CYAN}过滤完成。${NC}"
    fi
fi

# --- 阶段 B: 批量探测大小 ---
declare -a URL_LIST
declare -a NAME_LIST
declare -a SIZE_LIST
declare -a LABEL_LIST

TOTAL=$(wc -l < "$TEMP_LINKS" | xargs)
if [ "$TOTAL" -eq 0 ]; then echo -e "${RED}列表为空或所有文件已被过滤！${NC}"; exit 1; fi

echo -e "${CYAN}发现 $TOTAL 个文件，正在探测大小...${NC}"

count=0
while read -r line; do
    if [ -z "$line" ]; then continue; fi
    link=$(clean_url "$line")
    URL_LIST[$count]="$link"
    
    fname=$(basename "$link")
    fname=$(echo -e "${fname//%/\\x}") 
    NAME_LIST[$count]="$fname"

    echo -ne "\r[探测中] $((count+1))/$TOTAL : $fname ..."
    
    size_bytes=$(get_remote_size "$link")
    
    if [ -z "$size_bytes" ] || [ "$size_bytes" -eq 0 ]; then
        SIZE_LIST[$count]=0
        LABEL_LIST[$count]="未知"
    else
        SIZE_LIST[$count]=$size_bytes
        LABEL_LIST[$count]=$(bytes_to_mb "$size_bytes")
    fi
    ((count++))
done < "$TEMP_LINKS"
rm "$TEMP_LINKS"
echo -e "\n${GREEN}探测完成！${NC}"

# --- 阶段 C: 列表展示 ---
echo ""
echo -e "${BLUE}=== 最终下载清单 ===${NC}"
printf "${YELLOW}%-4s %-12s %-s${NC}\n" "ID" "大小" "文件名"
echo "----------------------------------------------"
for ((i=0; i<count; i++)); do
    printf "%-4d %-12s %-s\n" "$((i+1))" "${LABEL_LIST[$i]}" "${NAME_LIST[$i]}"
done
echo "----------------------------------------------"

# --- 阶段 D: 设置与下载 ---
read -p "设置最大跳过阈值 (MB, 0不限): " MAX_MB
MAX_MB=${MAX_MB:-0}
MAX_BYTES=$((MAX_MB * 1024 * 1024))

read -p "保存文件夹名: " DIRNAME
read -p "文件前缀 (留空则使用原名): " PREFIX
DIRNAME=${DIRNAME:-Downloads}

mkdir -p "$DIRNAME"
LOGFILE="$DIRNAME/log.txt"

echo ""
echo -e "${BLUE}=== 开始批量下载 ===${NC}"
echo -e "${YELLOW}提示: 按 [Ctrl+C] 跳过当前文件${NC}"
sleep 1

trap 'handle_interrupt' SIGINT

for ((i=0; i<count; i++)); do
    SKIP_CURRENT=0
    URL="${URL_LIST[$i]}"
    SIZE="${SIZE_LIST[$i]}"
    
    # 逻辑修改：如果用户没输前缀，就用原文件名
    if [ -z "$PREFIX" ]; then
        NEW_NAME="${NAME_LIST[$i]}"
    else
        NEW_NAME=$(printf "%s_%03d.%s" "$PREFIX" "$((i+1))" "${URL##*.}")
    fi
    
    SAVE_PATH="$DIRNAME/$NEW_NAME"

    # 1. 大小过滤
    if [ "$MAX_BYTES" -gt 0 ] && [ "$SIZE" -gt 0 ] && [ "$SIZE" -gt "$MAX_BYTES" ]; then
        echo -e "${RED}[自动跳过]${NC} 太大: ${LABEL_LIST[$i]} -> $NEW_NAME"
        echo "$URL | 跳过(过大) | ${LABEL_LIST[$i]}" >> "$LOGFILE"
        continue
    fi

    echo -e "正在下载: ${GREEN}$NEW_NAME${NC} [${LABEL_LIST[$i]}]..."

    # 2. 后台下载
    wget -c -q --show-progress -U "Mozilla/5.0" -O "$SAVE_PATH" "$URL" &
    PID=$!
    wait $PID
    EXIT_CODE=$?

    # 3. 结果处理
    if [ "$SKIP_CURRENT" -eq 1 ]; then
        echo -e "${YELLOW} -> 用户跳过。${NC}"
        rm -f "$SAVE_PATH"
        echo "$URL | 手动跳过 | -" >> "$LOGFILE"
        
        trap - SIGINT
        echo -e "${RED}已跳过。按任意键继续下一个... (3秒自动继续)${NC}"
        read -t 3 -n 1
        trap 'handle_interrupt' SIGINT
        
    elif [ "$EXIT_CODE" -eq 0 ]; then
        echo -e " -> ${GREEN}成功${NC}"
        echo "$URL | $NEW_NAME | 成功 | ${LABEL_LIST[$i]}" >> "$LOGFILE"
    else
        echo -e " -> ${RED}失败${NC}"
        echo "$URL | $NEW_NAME | 失败" >> "$LOGFILE"
    fi
    echo "-------------------"
done

trap - SIGINT
echo -e "${GREEN}任务全部结束。${NC}"
