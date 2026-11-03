"""
SteelSeries Sonar Lite - Database & Configuration Engine
Modifies SteelSeries GG configuration databases to enable pure Sonar mode with minimal footprint.
"""

import os
import sys
import shutil
import sqlite3
import argparse
from datetime import datetime

PROGRAM_DATA = os.environ.get("ProgramData", r"C:\ProgramData")
GG_DATA_DIR = os.path.join(PROGRAM_DATA, "SteelSeries", "GG")
GG_DB_DIR = os.path.join(GG_DATA_DIR, "db")
GGEZ_DB = os.path.join(GG_DB_DIR, "ggez.db")
DATABASE_DB = os.path.join(GG_DB_DIR, "database.db")


def check_paths():
    if not os.path.isdir(GG_DB_DIR):
        print(f"[!] Error: SteelSeries GG database folder not found at: {GG_DB_DIR}")
        return False
    if not os.path.isfile(GGEZ_DB):
        print(f"[!] Error: ggez.db not found at: {GGEZ_DB}")
        return False
    return True


def backup_databases():
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    for db_path in [GGEZ_DB, DATABASE_DB]:
        if os.path.isfile(db_path):
            backup_path = f"{db_path}.{timestamp}.bak"
            shutil.copy2(db_path, backup_path)
            # Also maintain a standard .original.bak if none exists
            orig_backup = f"{db_path}.original.bak"
            if not os.path.isfile(orig_backup):
                shutil.copy2(db_path, orig_backup)
            print(f"[+] Backed up: {os.path.basename(db_path)} -> {os.path.basename(backup_path)}")


def restore_databases():
    restored = 0
    for db_path in [GGEZ_DB, DATABASE_DB]:
        orig_backup = f"{db_path}.original.bak"
        if os.path.isfile(orig_backup):
            shutil.copy2(orig_backup, db_path)
            print(f"[+] Restored: {os.path.basename(orig_backup)} -> {os.path.basename(db_path)}")
            restored += 1
        else:
            # Find newest .bak
            baks = sorted([f for f in os.listdir(GG_DB_DIR) if f.startswith(os.path.basename(db_path)) and f.endswith(".bak")])
            if baks:
                latest = os.path.join(GG_DB_DIR, baks[-1])
                shutil.copy2(latest, db_path)
                print(f"[+] Restored latest backup: {baks[-1]} -> {os.path.basename(db_path)}")
                restored += 1
            else:
                print(f"[-] No backup found for: {os.path.basename(db_path)}")
    return restored > 0


def get_status():
    if not check_paths():
        return

    print("\n" + "=" * 55)
    print("      STEELSERIES GG SUB-APPS STATUS")
    print("=" * 55)

    try:
        conn = sqlite3.connect(GGEZ_DB)
        cur = conn.cursor()
        cur.execute("SELECT name, is_enabled, auto_start, executable_name FROM sub_apps")
        rows = cur.fetchall()
        conn.close()

        print(f"{'Sub-App':<18} | {'Enabled':<8} | {'AutoStart':<10} | {'Executable'}")
        print("-" * 55)
        for name, enabled, auto_start, exe in rows:
            en_str = "YES" if enabled else "no"
            as_str = "YES" if auto_start else "no"
            star = " (*)" if name == "sonar" else ""
            print(f"{name + star:<18} | {en_str:<8} | {as_str:<10} | {exe}")
        print("=" * 55)
    except Exception as e:
        print(f"[!] Failed to read status: {e}")


def apply_debloat(disable_engine=True):
    if not check_paths():
        return False

    backup_databases()

    try:
        conn = sqlite3.connect(GGEZ_DB)
        cur = conn.cursor()

        # Always ensure Sonar is enabled and set to auto_start
        cur.execute("UPDATE sub_apps SET is_enabled = 1, auto_start = 1 WHERE LOWER(name) = 'sonar'")

        # Ensure oldGG (core service needed by Sonar) is enabled
        cur.execute("UPDATE sub_apps SET is_enabled = 1, auto_start = 1 WHERE LOWER(name) = 'oldgg'")

        # Disable heavy bloat: Moments (video recording service), 3D Aim Trainer, Performance Coach
        cur.execute("UPDATE sub_apps SET is_enabled = 0, auto_start = 0 WHERE LOWER(name) IN ('moments', 'threedat', 'performancecoach')")

        # Disable Engine if requested (mice/keyboards/Prism RGB)
        if disable_engine:
            cur.execute("UPDATE sub_apps SET is_enabled = 0, auto_start = 0 WHERE LOWER(name) = 'engine'")
            print("[+] Engine (Mice/Keyboards/RGB sync) disabled for maximum lightness.")
        else:
            cur.execute("UPDATE sub_apps SET is_enabled = 1, auto_start = 1 WHERE LOWER(name) = 'engine'")
            print("[+] Engine (Mice/Keyboards/RGB sync) kept ENABLED.")

        # Disable automatic game scanning in application_settings
        cur.execute("UPDATE application_settings SET value = 'False' WHERE setting_key = 'enableAutomaticGameScanning'")

        conn.commit()
        conn.close()

        # Also update database.db if sub_apps exists there
        if os.path.isfile(DATABASE_DB):
            conn2 = sqlite3.connect(DATABASE_DB)
            cur2 = conn2.cursor()
            cur2.execute("UPDATE sub_apps SET is_enabled = 1, auto_start = 1 WHERE name = 'sonar'")
            if disable_engine:
                cur2.execute("UPDATE sub_apps SET is_enabled = 0, auto_start = 0 WHERE name = 'engine'")
            else:
                cur2.execute("UPDATE sub_apps SET is_enabled = 1, auto_start = 1 WHERE name = 'engine'")
            cur2.execute("UPDATE sub_apps SET is_enabled = 0, auto_start = 0 WHERE name IN ('threeDAT', 'moments')")
            cur2.execute("UPDATE settings SET value = 'false' WHERE setting_key = 'enableAutomaticGameScanning'")
            conn2.commit()
            conn2.close()

        print("[+] Debloat configuration successfully applied!")
        return True
    except Exception as e:
        print(f"[!] Error applying debloat: {e}")
        return False


def main():
    parser = argparse.ArgumentParser(description="SteelSeries Sonar Lite Configurator")
    parser.add_argument("--status", action="store_true", help="Display current status of sub-apps")
    parser.add_argument("--debloat", action="store_true", help="Apply Sonar-only debloat configuration")
    parser.add_argument("--keep-engine", action="store_true", help="When debloating, keep Engine enabled for SS mice/keyboards")
    parser.add_argument("--restore", action="store_true", help="Restore factory databases from backup")

    args = parser.parse_args()

    if args.status:
        get_status()
    elif args.restore:
        restore_databases()
        get_status()
    elif args.debloat:
        disable_engine = not args.keep_engine
        apply_debloat(disable_engine=disable_engine)
        get_status()
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
