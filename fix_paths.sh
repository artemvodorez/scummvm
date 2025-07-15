#!/bin/bash

# Назва вашого .app файлу
APP_NAME="The Legend of Kyrandia Book One.app"

# Зупинити скрипт при першій помилці
set -e

echo "=== Початок процедури виправлення шляхів ==="

# Перевірка, чи існує .app
if [ ! -d "$APP_NAME" ]; then
    echo "Помилка: Не можу знайти '$APP_NAME' у поточній папці."
    exit 1
fi

EXECUTABLE_PATH="$APP_NAME/Contents/MacOS/scummvm-real"
FRAMEWORKS_PATH="$APP_NAME/Contents/Frameworks"

# Список бібліотек, які ми скопіювали
LIBS_TO_PROCESS=(
  "libSDL2-2.0.0.dylib"
  "libvorbisfile.3.dylib"
  "libvorbis.0.dylib"
  "libFLAC.14.dylib"
  "libogg.0.dylib"
  "libjpeg.8.dylib"
  "libpng16.16.dylib"
  "libfreetype.6.dylib"
  "libfribidi.0.dylib"
)

# --- КРОК 1: Виправлення шляхів у головному файлі (scummvm-real) ---
echo "--- Виправлення головного файлу: scummvm-real ---"
for lib_name in "${LIBS_TO_PROCESS[@]}"; do
    # Знаходимо повний оригінальний шлях до бібліотеки
    original_path=$(otool -L "$EXECUTABLE_PATH" | grep "$lib_name" | grep '/usr/local/' | awk '{print $1}' || true)
    if [ -n "$original_path" ]; then
        echo "Змінюю шлях для $lib_name..."
        install_name_tool -change "$original_path" "@executable_path/../Frameworks/$lib_name" "$EXECUTABLE_PATH"
    fi
done

# --- КРОК 2: Виправлення внутрішніх залежностей у кожній бібліотеці ---
echo ""
echo "--- Виправлення внутрішніх залежностей бібліотек у Frameworks ---"
for lib_in_framework in "$FRAMEWORKS_PATH"/*.dylib; do
    echo "Перевірка: $(basename "$lib_in_framework")"

    # Знаходимо всі залежності цієї бібліотеки, що ведуть в /usr/local/
    dependencies_to_fix=$(otool -L "$lib_in_framework" | grep '/usr/local/' | awk '{print $1}' || true)

    if [ -z "$dependencies_to_fix" ]; then
        echo "  (немає поганих шляхів)"
        continue
    fi

    # Виправляємо кожну знайдену залежність
    echo "$dependencies_to_fix" | while read -r old_path; do
        dependency_name=$(basename "$old_path")
        echo "  Виправляю посилання на -> $dependency_name"
        install_name_tool -change "$old_path" "@executable_path/../Frameworks/$dependency_name" "$lib_in_framework"
    done
done

echo ""
echo "=== Готово! Фінальна перевірка всіх компонентів: ==="
echo ""
echo "Перевірка scummvm-real:"
otool -L "$EXECUTABLE_PATH" | grep 'Frameworks'
echo ""
echo "Перевірка бібліотек:"
otool -L "$FRAMEWORKS_PATH"/* | grep -E 'Frameworks|Name'

echo ""
echo "Процедуру завершено успішно!"
