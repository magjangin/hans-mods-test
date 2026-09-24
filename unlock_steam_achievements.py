import ctypes
import os
import sys

def unlock_steam():
    dll_candidates = [
        r"H:\steam\steamapps\common\HANS\Engine\Binaries\ThirdParty\Steamworks\Steamv153\Win64\steam_api64.dll",
        r"H:\steam\steamapps\common\HANS\Hans\Binaries\Win64\steam_api64.dll",
    ]
    
    dll_path = None
    for p in dll_candidates:
        if os.path.exists(p):
            dll_path = p
            break
            
    if not dll_path:
        print("[오류] steam_api64.dll을 찾을 수 없습니다.")
        return False

    os.environ["SteamAppId"] = "2616420"
    os.environ["SteamGameId"] = "2616420"

    try:
        steam_api = ctypes.CDLL(dll_path)
    except Exception as e:
        print(f"[오류] steam_api64.dll 로드 실패: {e}")
        return False

    steam_api.SteamAPI_Init.restype = ctypes.c_bool
    steam_api.SteamAPI_SteamUserStats_v012.restype = ctypes.c_void_p
    steam_api.SteamAPI_ISteamUserStats_RequestCurrentStats.argtypes = [ctypes.c_void_p]
    steam_api.SteamAPI_ISteamUserStats_RequestCurrentStats.restype = ctypes.c_bool
    steam_api.SteamAPI_ISteamUserStats_SetAchievement.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
    steam_api.SteamAPI_ISteamUserStats_SetAchievement.restype = ctypes.c_bool
    steam_api.SteamAPI_ISteamUserStats_StoreStats.argtypes = [ctypes.c_void_p]
    steam_api.SteamAPI_ISteamUserStats_StoreStats.restype = ctypes.c_bool

    if not steam_api.SteamAPI_Init():
        print("[안내] Steam 클라이언트가 실행 중이지 않거나 초기화에 실패했습니다.")
        return False

    user_stats = steam_api.SteamAPI_SteamUserStats_v012()
    if not user_stats:
        print("[오류] ISteamUserStats 인터페이스를 가져올 수 없습니다.")
        steam_api.SteamAPI_Shutdown()
        return False

    steam_api.SteamAPI_ISteamUserStats_RequestCurrentStats(user_stats)

    ach_names = [
        b"ACH_SKIN_1", b"ACH_HANS_1", b"ACH_JUMP_1000", b"ACH_HANS_10",
        b"ACH_JUMP_2500", b"ACH_JUMP_5000", b"ACH_HANS_50", b"ACH_ESCAPE",
        b"ACH_SKIN_10", b"ACH_HANS_100", b"ACH_HANS_3X", b"ACH_GOAL",
        b"ACH_HANS_200", b"ACH_RESTART_100", b"ACH_DUMPSTER", b"ACH_HANS_HARD",
        b"ACH_BASKET", b"ACH_FINISH_LEVEL", b"ACH_FINISH_30M", b"ACH_FINISH_WSM",
        b"ACH_SKIN_ALL", b"ACH_FINISH_WH"
    ]

    unlocked_count = 0
    for name in ach_names:
        if steam_api.SteamAPI_ISteamUserStats_SetAchievement(user_stats, name):
            unlocked_count += 1

    stored = steam_api.SteamAPI_ISteamUserStats_StoreStats(user_stats)
    steam_api.SteamAPI_Shutdown()

    if stored:
        print(f"[성공] Steam 도전과제 {unlocked_count}/{len(ach_names)}개 연동 및 서버 동기화 완료!")
        return True
    else:
        print(f"[경고] 도전과제 설정 완료({unlocked_count}개)되었으나 StoreStats 반환값 확인 필요")
        return True

if __name__ == "__main__":
    unlock_steam()
