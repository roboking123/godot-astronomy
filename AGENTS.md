<!-- 自動產生：sync-agents.ps1 -->
> 本檔由同層 `CLAUDE.md` 展開共用規則後自動產生，內容即完整規則，請直接遵守；勿手改。要改規則就改 `CLAUDE.md` 或 `D:\Projects\_shared\rules\`，再執行 `D:\Projects\_shared\sync-agents.ps1`。

# Godot 專案規則

適用 `D:\Projects\Godot\` 下全部專案；各專案 `CLAUDE.md` 開頭以 `@../../_shared/rules/godot.md` 匯入。

## 專案與素材

- 外部原件是 `ref-` 前綴的專案；UDS 的 UE 對拍基準為 `D:\My_Works\UE_Projects\UDS97_Template`，擷取專案為 `UDS97Extract`。授權隔離素材與閉源衍生內容不可混入公開插件。
- 新建 Godot 專案的 `project.godot` 的 `config/name` 用中文「分類：名稱」（如「草地：花圃角落」）並加 `config/tags`；Godot 專案管理員關閉時把路徑登記進 `%APPDATA%\Godot\projects.cfg`。收工時從 `projects.cfg` 移除已不存在的路徑。
- 設計內容系統（物品、任務、商店等資料庫）、討論 mod／創意工坊／DLC 開放、或新專案起架構時，先讀 `mod-friendly-architecture` skill。
- 開始或整理 Fab（或其他商店）資產移植、新增擷取或匯出流程、考慮換引擎時，先讀 `fab-port` skill。
- 外掛統一放 `D:\Dev_Tools\Godot\addons-library`，從那裡用 `install-addons.bat` 裝到指定專案。外掛入庫或進專案前，GDExtension 只留 Windows 二進位（雙機皆 Windows）。

## 多插件整合（2026-10-24 拍板）

- 遵循語意化版本（`Semantic Versioning`）與重用／發布等價原則（`Reuse/Release Equivalence Principle`）；自製插件各自一個倉庫與版本號，一起升版的功能放在同一個插件。
- 遵循依賴管理（`Dependency Management`）與可重現建置（`Reproducible Builds`）；整合專案以清單取得插件，並以鎖檔（`Lockfile`）記錄來源與提交，不手動複製；同步進來的 `addons/` 不進該專案版控。
- 遵循無環依賴原則（`Acyclic Dependencies Principle`）與依賴反轉原則（`Dependency Inversion Principle`）；插件之間不直接引用，跨插件串接只放在整合專案的組合根（`Composition Root`），以轉接器（`Adapter Pattern`）寫成。
- 插件要支援另一個插件時採可選依賴（`Optional Dependency`）：執行期偵測到才接。同一種共用資料有三個以上插件需要時，才抽成只含介面與資料格式的共用合約插件（`Rule of Three`）。
- 遵循命名空間（`Namespacing`）；`class_name`、全域 shader 參數、autoload、輸入動作與專案設定一律加插件前綴；插件需要的專案設定由 `plugin.gd` 啟用時註冊。
- 整合專案兼作整合測試（`Integration Testing`）：任一插件升版後，在整合專案跑匯入與基準截圖。

## 程式碼規範

- 所有變數與函式標註靜態型別；縮排用 Tab。
- 註解只寫意思、目的、單位、文獻與雙值標記（如〔物理 0.9／UDS 0.225〕），一至三行；換算推導、歷史與量測過程不寫進註解，有價值的結論放 `docs/`（2026-08-06 拍板）。
- 刪檔前先說明理由。
- `@export` 可調參數用繁體中文命名（如 `銀河亮度`），內部變數維持英文 snake_case。
- `.tres` 禁止循環引用（A→B→A 會損毀檔案）。
- 變數、參數與 shader UBO 欄位從名字就看得出單位與空間，禁止無後綴的裸數值；不同空間的座標不混傳，參數名標錯空間最優先修；跨引擎搬運標明軸向（Y-up／Z-up）並明確換算。常用後綴：距離 `_km` `_m` `_cm`；角度 `_rad` `_deg`（Godot API 弧度與角度混用）；正規化 `_01` `_pct`；空間 `_world` `_local` `_view` `_screen` `_ndc` `_uv` `_tangent`。

## 引擎與指令

- 共用標準版入口為 `D:\Dev_Tools\Godot\godot.exe` 與 `godot_console.exe`，供 GDScript 專案使用；版本以 `D:\Dev_Tools\Godot\README.md` 與執行檔版本資料為準。只有明確使用 C# 的專案才用 .NET 入口，不能以 .NET 版覆蓋標準版入口。
- 工作列經 `godot-launcher.py` 啟動；更新共用引擎後執行 `C:\Python314\python.exe D:\Dev_Tools\Godot\godot-launcher.py --sync-only`，維護說明見 `D:\Projects\_shared\.claude\tools\godot-launcher.md`。
- 實作功能前確認專案引擎版本、最低支援版本與渲染器，查對應版本官方文件是否已有原生做法；符合需求時優先用原生節點與 API。採用新版限定功能要記錄最低版本與遷移影響，不因文件較新就自行提高最低支援版本。
- bash 一律用 `godot_console.exe`（會等結束並拿得到輸出）。以下指令都在隔離桌面入口內執行：
  - 編譯檢查：`godot_console.exe --headless --quit`
  - GUT：`godot_console.exe --headless -d -s addons/gut/gut_cmdln.gd -gexit`
  - 更新快取（新增 class_name 後必跑）：`godot_console.exe --headless --import --quit`
- 改 `.glslinc` 後必須刪 `.godot/imported/<主檔名>.glsl-*.res` 再 `--import`；匯入只看主檔雜湊，否則執行期跑舊 SPIR-V 而測試照樣全綠。
- 新專案預設有邊框最大化視窗（`window/size/mode=2`、`window/stretch/mode="canvas_items"`），除非使用者要求不用全螢幕；不以基準解析度宣稱實際像素尺寸。

## 自動測試的桌面隔離

- 所有自動測試、GPU 渲染驗證與引擎匯入都在隔離桌面執行（使用者自己開展示或編輯器除外）：用 `D:\Projects\_shared\.claude\tools\Run-IsolatedTest.ps1 -Executable <絕對路徑> -ArgumentList <陣列> -WorkingDirectory <專案絕對路徑> -LogPath <日誌絕對路徑> -TimeoutSeconds 60`（日誌父目錄須先存在），或由專案測試入口載入 `Isolated-Desktop.ps1` 呼叫 `[GodotIsolatedDesktop]::Run()`。Python 等外層測試程序也放進同一隔離桌面。
- 原理：`CreateDesktop` 建專用桌面，`CreateProcess` 以 `lpDesktop` 指定並隱藏視窗，不呼叫 `SwitchDesktop`；逾時只終止本次程序。2026-09-07 實測 D3D12 GPU 渲染通過且不閃窗。只用 `Start-Process -WindowStyle Hidden` 或 `root.hide()` 仍會閃窗，不能替代。隔離失敗就停止回報，不退回使用者桌面。
- 腳本對 Godot 自動加 `--audio-driver Dummy` 並設 `GODOT_ISOLATED_TEST=1`；受測場景見到它就不得設 `MOUSE_MODE_CAPTURED`／`CONFINED`（滑鼠鎖定作用於整個工作階段，不能用焦點判斷）。
- `--headless` 只是無視窗渲染模式，不取代隔離，也不能代替 GPU 驗證。
- 遇到 `ISOLATION_PROFILE_MISMATCH`，以核准的正常使用者身分重跑同一指令（Codex 用 `sandbox_permissions=require_escalated`），不繞過隔離。退出碼與日誌判定見 `D:\Projects\_shared\.claude\tools\isolation-diagnostics.md`；Vulkan 附加層通知也要回報，不能稱零警告。

## 驗證

- runtime 錯誤一律重跑 `python3 addons/error_sink/headless_runner.py --project . --timeout 10`（不要讀舊的 `error_sink_latest.json`）；errors 非空就修到空。有 GUT 就跑。
- 警告逐條處理：自己的程式能修就修，第三方插件不可修的登記為已知問題；每輪改完 `.gd` 重掃，過濾噪音時不可濾掉 `deprecated`。
- `gdscript-warn-guard` hook 會在改完 `.gd` 後列出警告（說明見 `~/.claude/hooks/gdscript-warn-guard.README.md`），它不擋工具呼叫，所以每條都要有結論：改掉；或加 `@warning_ignore("代碼")` 並在回覆說明為何保留；或判不出來就收尾時列給使用者。使用者不懂程式，判斷與回報責任在 AI。hook 只涵蓋七類，遇到編輯器有報、hook 沒報的，記下「檔名:行號＋警告全文＋原始碼」，收尾時提一句。
- 截圖：AI 預設不判讀外觀，截圖存檔傳給使用者判讀，只陳述拍了什麼狀態。使用者當輪明示「你自己看」才可自看粗判，授權只限該輪；外觀定案永遠是使用者。
- 判斷畫面對比、變化或失真時寫探針算數字（std、百分位、對比幅），不肉眼下結論；尺寸與比例也要用像素量測或密度場探針，不用名目參數心算。
- 原版對拍必須同一模擬時刻：兩邊固定 60 fps 步長、相機先就位、快門落在目標幀，記錄並核對實際時間；時間不一致不下結論（2026-10-25 拍板）。範例工具：`D:\My_Works\UE_Projects\FluidNinjaLive\Compare`。

## 測試截圖與烘焙

- 測試截圖統一放 `<專案根>/test_shots/<主題>/`，目錄必含 `.gdignore`；不散落在 sandbox、工具旁或暫存區。使用者定案的當下就刪掉該輪照片；開工發現殘留舊照也主動清。
- `NoiseTexture2D/3D` 等程序紋理禁止直接掛進場景（每次啟動在主執行緒重算，東末實測 5 張共 4.4 秒）；離線烘焙成 `ImageTexture`／`ImageTexture3D` 的 `.res` 進版控，參數 `.tres` 留在旁邊供重烘（範本：東末 `sandbox/forest_lake_scene/tools/bake_noise_textures.gd`）。例外是編輯器預覽或需 runtime 動態改，要寫註解。
- 走 RenderingServer 的資料（MultiMesh、instancer）必須開視窗烘焙；headless 下烘出來是空的且不報錯。
- 使用者編輯器開著時，定案參數寫進腳本 `@export` 預設值，不寫成場景新屬性（編輯器存檔會丟掉它不認得的屬性）。

## 效能預算（2026-10-10 拍板）

- 遵循效能預算（`Performance Budget`）與避免過早優化（`Premature Optimization`）；基準 4K、60 FPS（每幀 16.7 ms），多插件合計不得超出。
- 每個插件或系統在自己的 `docs/` 維護成本表：各功能開關前後的 CPU 中位／P95 與 GPU 中位增量，註明場景、天氣與解析度；改逐幀邏輯或渲染效果時同步更新，沒有量測不得宣稱成本低。主專案（東末）維護合計表，逼近預算時回報使用者取捨。
- 熱點由大到小處理，依序改演算法、移到 GPU、改 C++（GDExtension）；每次量前後數字，沒改善就退回。健壯性優先於效能，衝突時回報使用者。

## 踩坑與安全

- 分幀攤提或依賴上一幀緩衝的系統（時域抗鋸齒、自動曝光、探針輪更、累積緩衝等）設計時就定編輯器策略：編輯器走全量或凍結，多視口共用歷史即停用；F5 與編輯器預覽分開驗收。
- spatial shader 畫天空：`unshaded` 下輸出走 `ALBEDO`（`EMISSION` 被忽略）；從球內看穹頂用 `cull_back`；Forward+ 反向 Z，最遠是 `POSITION.z = 0.0`；`fragment()` 不能 `return`。
- Autoload 的 `_process()` 存取場景節點前必查 `is_instance_valid(ref) and ref.is_inside_tree()`。
- 新增按鍵處理前先搜同一 action 是否已有人用，衝突走責任鏈。
- 多系統共用的引擎屬性（`material_override`、`collision_layer` 等）透過管理者元件寫，不直寫；重複邏輯抽到基底類別。
- 型別陣列的條件指派拆成 if 寫：`x if cond else []` 是無型別 Array，指派給 `Array[int]` 會在執行期靜默出錯。
- 手寫或批次生成 `.tres` 時，非 ASCII 屬性名必加雙引號（`"事件ID" = &"base:x"`），否則解析器靜默跳過。
