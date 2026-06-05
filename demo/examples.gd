extends SceneTree
## 常見用法範例 — 複製貼上就能跑
## 執行方式：godot --headless -s demo/examples.gd


func _init() -> void:
	print("")
	print("═══════════════════════════════════════")
	print("  Godot Astronomy — 常見用法範例")
	print("═══════════════════════════════════════")
	print("")

	example_1_sun_position()
	example_2_sunrise_sunset()
	example_3_moon_info()
	example_4_planet_position()
	example_5_next_full_moon()
	example_6_all_in_one()
	example_7_celestial_state_helpers()

	print("")
	print("═══════════════════════════════════════")
	print("  全部範例執行完畢")
	print("═══════════════════════════════════════")
	quit()


# ─────────────────────────────────────────────────
# 範例 1：太陽現在在天空的哪裡？
# ─────────────────────────────────────────────────
# 最基本的用法。給一個時間和地點，拿到太陽的方位角和仰角。
#
# 方位角（azimuth）：0° = 正北，90° = 正東，180° = 正南，270° = 正西
# 仰角（altitude）：正值 = 地平線以上，負值 = 地平線以下
#
# 步驟：
#   1. 用 AstroTime.make_time() 建立時間物件（所有時間一律用 UTC）
#   2. 用 AstroSun.sun_position() 拿到太陽在宇宙中的座標
#   3. 用 AstroCoords 轉換成觀測者看到的方位角/仰角

func example_1_sun_position() -> void:
	print("── 範例 1：太陽現在在天空的哪裡？ ──")

	# UTC 時間 2026-06-04 06:30（= 台北時間 14:30）
	var time: AstroTime.Moment = AstroTime.make_time(2026, 6, 4, 6, 30, 0.0)

	# 太陽的宇宙座標（J2000 赤道座標系，單位 AU）
	var sun_j2000: Vector3 = AstroSun.sun_position(time)

	# 轉成赤經/赤緯
	var ofdate: Vector3 = AstroCoords.j2000_to_ofdate(sun_j2000, time)
	var radec: AstroCoords.RaDec = AstroCoords.vector2radec(ofdate)

	# 轉成地平座標（台北 25.033°N, 121.565°E）
	var hor: AstroCoords.HorizonCoord = AstroCoords.horizon(
		time, 25.033, 121.565, radec.ra, radec.dec
	)

	print("  方位角: %.1f°（0=北 90=東 180=南 270=西）" % hor.azimuth)
	print("  仰角:   %.1f°（正=在地平線上）" % hor.altitude)
	print("  距離:   %.6f AU" % sun_j2000.length())
	print("")


# ─────────────────────────────────────────────────
# 範例 2：今天日出日落幾點？
# ─────────────────────────────────────────────────
# search_rise_set() 從指定時間往未來搜「下一次日出/日落」。
#
# ⚠️ 重要：所有 API 都用 UTC 時間。
#    如果你在 UTC+8 的台北，「今天」的起點不是 UTC 00:00，
#    而是 UTC 前一天 16:00（= 當地午夜）。
#    起始時間選錯，搜出的日出日落會跑到不同天。
#
# 公式：UTC 起始 = 當地午夜 - 時區偏移小時
#    台北 6/4 00:00 = UTC 6/3 16:00（24 - 8 = 16）
#    紐約 6/4 00:00 = UTC 6/4 04:00（24 - (-4) = 28 → 隔天 04:00）

func example_2_sunrise_sunset() -> void:
	print("── 範例 2：今天日出日落幾點？ ──")

	# 你的時區偏移（台北 = +8，紐約 = -4，倫敦 = 0）
	var utc_offset: int = 8
	# 當地日期
	var local_year: int = 2026
	var local_month: int = 6
	var local_day: int = 4

	# 換算成 UTC 午夜：當地 6/4 00:00 = UTC 6/3 16:00
	var start: AstroTime.Moment = AstroTime.make_time(
		local_year, local_month, local_day, -utc_offset, 0, 0.0
	)

	# 搜 1 天內的日出
	var sunrise: Variant = AstroSearch.search_rise_set(
		AstroSearch.Body.SUN, AstroSearch.Direction.RISE,
		25.033, 121.565, 0.0,  # 緯度、經度、海拔（公尺）
		start, 1.0             # 從 start 開始，搜 1 天
	)

	# 搜 1 天內的日落（從日出之後開始搜，保證順序正確）
	var sunset_start: AstroTime.Moment = sunrise as AstroTime.Moment if sunrise != null else start
	var sunset: Variant = AstroSearch.search_rise_set(
		AstroSearch.Body.SUN, AstroSearch.Direction.SET,
		25.033, 121.565, 0.0,
		sunset_start, 1.0
	)

	if sunrise != null:
		print("  日出 UTC: J2000 day %.6f" % (sunrise as AstroTime.Moment).ut)
	else:
		print("  今天沒有日出（可能在極區）")

	if sunset != null:
		print("  日落 UTC: J2000 day %.6f" % (sunset as AstroTime.Moment).ut)
	else:
		print("  今天沒有日落（可能在極區）")

	# 計算日照時數
	if sunrise != null and sunset != null:
		var hours: float = ((sunset as AstroTime.Moment).ut - (sunrise as AstroTime.Moment).ut) * 24.0
		print("  日照時數: %.1f 小時" % hours)
	print("")


# ─────────────────────────────────────────────────
# 範例 3：月亮資訊 — 位置、距離、月相、亮面比例
# ─────────────────────────────────────────────────
# AstroMoon 負責月球位置，AstroEngine.moon_phase() 算月相。
# CelestialState.phase_name() 把角度翻譯成「上弦月」「滿月」等名稱。

func example_3_moon_info() -> void:
	print("── 範例 3：月亮資訊 ──")

	var time: AstroTime.Moment = AstroTime.make_time(2026, 6, 4, 6, 30, 0.0)

	# 月球宇宙座標 + 中間值
	var geo: AstroMoon.GeoMoonResult = AstroMoonMeeus.geo_moon(time)

	# 天秤動 + 距離 + 視直徑
	var lib: AstroMoon.LibrationResult = AstroMoon.libration(time, geo.ecliptic, geo.tobl)

	# 月相（需要太陽位置來算夾角）
	var sun_j2000: Vector3 = AstroSun.sun_position(time)
	var phase_deg: float = AstroEngine.moon_phase(sun_j2000, geo.j2000, time)

	print("  距離:     %.0f km" % lib.dist_km)
	print("  視直徑:   %.4f°" % lib.diam_deg)
	print("  月相角度: %.1f°（0=新月 180=滿月）" % phase_deg)
	print("  月相名稱: %s" % CelestialState.phase_name(phase_deg))
	print("  亮面比例: %.0f%%" % (CelestialState.phase_to_illumination(phase_deg) * 100.0))
	print("")


# ─────────────────────────────────────────────────
# 範例 4：行星在哪裡？
# ─────────────────────────────────────────────────
# AstroPlanets 有一個快捷函數 planet_horizon()，
# 直接給年月日時分秒 + 緯經度，回傳方位角和仰角。
# 不用自己串 AstroTime → position → coords → horizon。

func example_4_planet_position() -> void:
	print("── 範例 4：行星在哪裡？ ──")

	var planets: Array[AstroPlanets.Planet] = [
		AstroPlanets.Planet.MARS,
		AstroPlanets.Planet.JUPITER,
		AstroPlanets.Planet.SATURN,
	]
	var names: Array[String] = ["Mars", "Jupiter", "Saturn"]

	for i: int in planets.size():
		var hor: AstroCoords.HorizonCoord = AstroPlanets.planet_horizon(
			planets[i],
			2026, 6, 4, 6, 30, 0.0,  # UTC 時間
			25.033, 121.565            # 觀測地點
		)
		var status: String = "在地平線上" if hor.altitude > 0.0 else "在地平線下"
		print("  %s: 方位 %.1f°  仰角 %.1f°  %s" % [names[i], hor.azimuth, hor.altitude, status])
	print("")


# ─────────────────────────────────────────────────
# 範例 5：下一次滿月是什麼時候？
# ─────────────────────────────────────────────────
# search_moon_phase() 搜尋月亮到達指定相位角的時刻。
# 0° = 新月，90° = 上弦，180° = 滿月，270° = 下弦。

func example_5_next_full_moon() -> void:
	print("── 範例 5：下一次滿月 ──")

	var start: AstroTime.Moment = AstroTime.make_time(2026, 6, 4, 0, 0, 0.0)

	# 搜 30 天內的滿月（180°）
	var full_moon: Variant = AstroSearch.search_moon_phase(180.0, start, 30.0)
	if full_moon != null:
		print("  下一次滿月 UTC: J2000 day %.6f" % (full_moon as AstroTime.Moment).ut)

	# 搜 30 天內的新月（0°）
	var new_moon: Variant = AstroSearch.search_moon_phase(0.0, start, 30.0)
	if new_moon != null:
		print("  下一次新月 UTC: J2000 day %.6f" % (new_moon as AstroTime.Moment).ut)
	print("")


# ─────────────────────────────────────────────────
# 範例 6：一次算完所有東西
# ─────────────────────────────────────────────────
# AstroEngine.compute() 是最懶人的用法 —
# 一個呼叫就拿到太陽、月亮、恆星時的全部資料。
# 適合「我只想知道現在天空長什麼樣」的情境。

func example_6_all_in_one() -> void:
	print("── 範例 6：AstroEngine.compute() 一次搞定 ──")

	var r: AstroEngine.CelestialResult = AstroEngine.compute(
		2026, 6, 4, 6, 30, 0.0,  # UTC 時間
		25.033, 121.565            # 台北
	)

	print("  太陽  方位 %.1f°  仰角 %.1f°  距離 %.4f AU" % [r.sun_az, r.sun_alt, r.sun_dist])
	print("  月亮  方位 %.1f°  仰角 %.1f°  距離 %.0f km" % [r.moon_az, r.moon_alt, r.moon_dist_km])
	print("  月相  %.1f°（%s）  亮面 %.0f%%" % [
		r.moon_phase_deg,
		CelestialState.phase_name(r.moon_phase_deg),
		CelestialState.phase_to_illumination(r.moon_phase_deg) * 100.0
	])
	print("  恆星時 %.4f 小時" % r.sidereal_time)
	print("")


# ─────────────────────────────────────────────────
# 範例 7：工具函數 — 方位角轉 Godot 方向、亮度建議
# ─────────────────────────────────────────────────
# CelestialState 有幾個靜態工具函數，
# 幫你把天文數據接進遊戲引擎：
#   - az_alt_to_direction()：方位角/仰角 → Godot 世界座標方向
#   - altitude_to_energy()：太陽仰角 → 建議燈光強度（0~1）
#   - altitude_to_darkness()：太陽仰角 → 天空暗度（0~1）
#
# 這些函數在你手動控制燈光時很有用。
# 如果用 CelestialBody 節點，它內部已經在用這些了。

func example_7_celestial_state_helpers() -> void:
	print("── 範例 7：工具函數 ──")

	# 方位角/仰角 → Godot 方向向量
	var dir: Vector3 = CelestialState.az_alt_to_direction(180.0, 45.0)
	print("  正南方、仰角 45° → 方向 %s" % str(dir))

	# 不同太陽仰角的建議亮度
	for alt: float in [60.0, 10.0, 0.0, -6.0, -12.0, -18.0]:
		var energy: float = CelestialState.altitude_to_energy(alt)
		var darkness: float = CelestialState.altitude_to_darkness(alt)
		print("  太陽 %+.0f° → 亮度 %.0f%%  暗度 %.0f%%" % [alt, energy * 100.0, darkness * 100.0])
	print("")
