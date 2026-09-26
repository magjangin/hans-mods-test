import ctypes
import os

GAME_DIR = r"H:\steam\steamapps\common\HANS"
STEAM_APP_ID = "2616420"

DLL_CANDIDATES = [
    os.path.join(GAME_DIR, r"Engine\Binaries\ThirdParty\Steamworks\Steamv153\Win64\steam_api64.dll"),
    os.path.join(GAME_DIR, r"Hans\Binaries\Win64\steam_api64.dll"),
]

ACHIEVEMENTS = [
    b"ACH_SKIN_1", b"ACH_HANS_1", b"ACH_JUMP_1000", b"ACH_HANS_10",
    b"ACH_JUMP_2500", b"ACH_JUMP_5000", b"ACH_HANS_50", b"ACH_ESCAPE",
    b"ACH_SKIN_10", b"ACH_HANS_100", b"ACH_HANS_3X", b"ACH_GOAL",
    b"ACH_HANS_200", b"ACH_RESTART_100", b"ACH_DUMPSTER", b"ACH_HANS_HARD",
    b"ACH_BASKET", b"ACH_FINISH_LEVEL", b"ACH_FINISH_30M", b"ACH_FINISH_WSM",
    b"ACH_SKIN_ALL", b"ACH_FINISH_WH",
]


def load_steam_api():
    dll_path = next((p for p in DLL_CANDIDATES if os.path.exists(p)), None)
    if not dll_path:
        print("[오류] steam_api64.dll을 찾을 수 없습니다.")
        return None

    try:
        api = ctypes.CDLL(dll_path)
    except OSError as e:
        print(f"[오류] steam_api64.dll 로드 실패: {e}")
        return None

    api.SteamAPI_Init.restype = ctypes.c_bool
    api.SteamAPI_SteamUserStats_v012.restype = ctypes.c_void_p
    api.SteamAPI_ISteamUserStats_RequestCurrentStats.argtypes = [ctypes.c_void_p]
    api.SteamAPI_ISteamUserStats_RequestCurrentStats.restype = ctypes.c_bool
    api.SteamAPI_ISteamUserStats_SetAchievement.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
    api.SteamAPI_ISteamUserStats_SetAchievement.restype = ctypes.c_bool
    api.SteamAPI_ISteamUserStats_StoreStats.argtypes = [ctypes.c_void_p]
    api.SteamAPI_ISteamUserStats_StoreStats.restype = ctypes.c_bool
    return api


def unlock_steam():
    os.environ["SteamAppId"] = STEAM_APP_ID
    os.environ["SteamGameId"] = STEAM_APP_ID

    api = load_steam_api()
    if not api:
        return False

    if not api.SteamAPI_Init():
        print("[안내] Steam 클라이언트가 실행 중이지 않거나 초기화에 실패했습니다.")
        return False

    try:
        user_stats = api.SteamAPI_SteamUserStats_v012()
        if not user_stats:
            print("[오류] ISteamUserStats 인터페이스를 가져올 수 없습니다.")
            return False

        api.SteamAPI_ISteamUserStats_RequestCurrentStats(user_stats)
        unlocked = sum(bool(api.SteamAPI_ISteamUserStats_SetAchievement(user_stats, name)) for name in ACHIEVEMENTS)
        stored = api.SteamAPI_ISteamUserStats_StoreStats(user_stats)
    finally:
        api.SteamAPI_Shutdown()

    if stored:
        print(f"[성공] Steam 도전과제 {unlocked}/{len(ACHIEVEMENTS)}개 연동 및 서버 동기화 완료!")
    else:
        print(f"[경고] 도전과제 설정 완료({unlocked}개)되었으나 StoreStats 반환값 확인 필요")
    return True


if __name__ == "__main__":
    unlock_steam()
