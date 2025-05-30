# VirtualBox 開啟共用剪貼簿 共用資料夾步驟
## 手動安裝方法 只安裝到當前 kerenl (剛開機以後 啥事都別做 直接裝 否則容易出錯)
https://medium.com/%E8%8A%B1%E5%93%A5%E7%9A%84%E5%A5%87%E5%B9%BB%E6%97%85%E7%A8%8B/%E8%A7%A3%E6%B1%BAvirtualbox%E7%84%A1%E6%B3%95%E9%9B%99%E5%90%91%E8%A4%87%E8%A3%BD%E8%B2%BC%E4%B8%8A-1554d5a81da0
# 如果換了kernel以後照做 還是無法共用剪貼簿 可以試試下面
# # 停止現有服務
sudo pkill VBoxClient

# # 手動啟動剪貼簿、拖放和顯示服務
sudo VBoxClient --clipboard
sudo VBoxClient --draganddrop
sudo VBoxClient --display



################################################# 安裝kernel ########################################################

# 可以在別台電腦上做 下載修改編譯linux kernel
wget https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.15.71.tar.xz
tar xvf linux-5.15.71.tar.xz
cd linux-5.15.71
make -j4 mrproper # 清除舊的配置檔案和暫存檔案

make menuconfig # 編輯 kernel 設定 保存為".config" 即可直接覆蓋配置
	# 在 menuconfig 裡面裡可用 / 搜尋下面大寫的參數 以找到位置
	# 找到後按 1 可以直接跳轉到位置
	# Make CONFIG_SYSTEM_TRUSTED_KEYS and CONFIG_SYSTEM_REVOCATION_KEYS empty # 取消簽名
	# Disable CONFIG_DEBUG_INFO_BTF # 取消 BTF

	# 修改自訂名稱
	# 在 General setup -> Local version - append to kernel release
	# 名稱只能使用英文, 數字, ".", "-" 不可使用 "_" 和空格
	

# 修改 kernel 印出 dmesg
# kernel/sched/deadline.c 當中的 __setparam_dl() 最底下新增:
printk(KERN_INFO "SCHED_DEADLINE parameters set on pid %d: runtime=%llu, deadline=%llu, period=%llu\n",
	   p->pid, attr->sched_runtime, attr->sched_deadline, attr->sched_period); # printk 和 printf 差異是 printk 會印到 kernel log buffer 可以從 dmesg 看到


# 修改kernel 將 earliest_deadline_first 改成 shortest_job_first
# 同樣打開 kernel/sched/deadline.c 找到 static inline bool __dl_less(struct rb_node *a, const struct rb_node *b)
# 將 return dl_time_before(__node_2_dle(a)->deadline, __node_2_dle(b)->deadline); 改成
	return __node_2_dle(a)->runtime < __node_2_dle(b)->runtime;


make -j6


# 在電腦上安裝剛剛自己編譯的 kernel (最後此電腦會有兩個 kernel)
sudo apt-get install build-essential libncurses5-dev flex bison libssl-dev libelf-dev dwarves zstd

sudo make modules_install # 安裝 kernel module 到 /lib/modules
sudo make install # 安裝 kernel 到 /boot

sudoedit /etc/default/grub # 編輯 bootloader (grub) 設定檔
	Configure the following 2 items
		GRUB_TIMEOUT_STYLE=menu # 顯示選單
		GRUB_TIMEOUT=10 # 等待 10 秒
sudo update-grub # 更新 bootloader (grub)
sudo reboot # 重新啟動電腦


# 如果重複用相同名稱安裝 舊的 kernel 會被自動備份成 .old 檔案
################################################# 刪除kernel ########################################################

# 0. 列出所有已安裝的 kernel 版本 (要 make install 以後才會出現) (自己安裝的 kernel 用 apt 會看不到)
ls /boot/vmlinuz* # /boot/vmlinuz  /boot/vmlinuz-5.15.71  /boot/vmlinuz-5.15.71.old  /boot/vmlinuz-6.11.0-21-generic  /boot/vmlinuz-6.11.0-26-generic  /boot/vmlinuz.old


# 1. 目前使用的 kernel 版本
uname -a

# 2. 移除特定的舊版本和其 .old 檔案
sudo rm /boot/*vmlinuz-5.15.71.old
sudo rm /boot/*vmlinuz.old

# 3. 更新 GRUB
sudo update-grub

################################################# 測試排程方法 ########################################################
# 設 CPU 1, RAM 4GB
# 安裝壓縮工具與影片撥放器
sudo apt install 7zip mpv


# 在終端1解壓縮
7z b 10000 -md16 # b benchmark模式(會自動產生虛擬檔案), 10 壓縮解壓次數, md16 字典大小為2^16=64KB

# 在終端2運行影片播放 強制 720p fps=24 (影片撥放中按I顯示詳細資訊)
mpv --loop=inf --geometry=1280x720 --vf=fps=24 test.mp4

# 在終端3觀察效能
mpstat 5 # 顯示 CPU 的各種統計資訊，每5秒更新一次

# 在終端4設定排程方法
# 指令readme.md當中有詳細說明


pgrep mpv # 取得 mpv 的 PID


# 查看/修改當前終端進程的排程策略與優先權
chrt -p $$ # $$ 代表當前終端的 PID
# -p 用於修改pid，不知道PID的話，可以使用pgreg <進程名>取得。沒用-p的話，要直接提供CLI指令。
# -f FIFO
# -r RR
# -o OTHER (linux預設的CFS完全公平調度)

# 查看所有支援的排程方法 與對應優先權範圍 數字越大越高
chrt -m


# 查看內核日誌
sudo dmesg | grep "SCHED_DEADLINE"