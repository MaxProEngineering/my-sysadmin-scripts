#!/bin/bash
set -euo pipefail

# Ниже указаны дефолтные значения
LOGFILE="${LOGFILE:-/var/log/syslog}"
REPORT="selectedTimeIntervalErrorsReport.txt"
START_TIME=""
END_TIME=""
PATTERNS="error|fail"

# Вывод Cправки
show_help() 
{
  cat << 'EOF'

#Скрипт ищет в системном журнале строки с ошибками только за нужный интервал времени (например, с "2026-10-11 09:45" до "2026-10-11 15:10") и сохраняет их в отчёт selectedTimeIntervalErrorsReport.txt. При этом, в консоль выводится информация об общем количество строк с ошибками (из заданного временного интервала), а также последние 20 строк с ошибками (также из заданного интервала).

Команда: ./selectedTimeIntervalErrors_script.sh [указать выбранный(ые) ниже вариант(ы)]
Варианты:
  -f, --file <путь>       Путь к лог-файлу (по умолчанию: /var/log/syslog)
  -o, --output <файл>     Имя файла отчёта (по умолчанию: selectedTimeIntervalErrorsReport.txt)
  -s, --start <дата>      Начало интервала поиска (например: "2026-10-11 09:45")
  -e, --end <дата>        Конец интервала поиска (например: "2026-10-11 15:10")
  -p, --patterns <шаблон> Регулярное выражение для поиска ошибок (по умолчанию: error|fail)
  -h, --help              Показать Справку и выйти

Примеры:
  # Поиск всех ошибок за временной интервал с "2026-10-11 09:45" до "2026-10-11 15:10"
  ./selectedTimeIntervalErrors_script.sh -s "2026-10-11 09:45" -e "2026-10-11 15:10"

  # Поиск всех ошибок за период с 11:00 до 14:00 сегодня
  ./selectedTimeIntervalErrors_script.sh -s "today 11:00" -e "today 14:00"

  # Поиск всех ошибок за последние 2 часа
  ./selectedTimeIntervalErrors_script.sh -s "2 hours ago"

  # Поиск конкретных ошибок в auth.log
  ./selectedTimeIntervalErrors_script.sh -f /var/log/auth.log -p "failed|denied"

  # Поиск всех ошибок в syslog без ограничений по временному интервалу
  ./selectedTimeIntervalErrors_script.sh
EOF
}

# Парсер аргументов командной строки
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      show_help
      exit 0
      ;;
    -f|--file)
      LOGFILE="$2"
      shift 2
      ;;
    -o|--output)
      REPORT="$2"
      shift 2
      ;;
    -s|--start)
      START_TIME="$2"
      shift 2
      ;;
    -e|--end)
      END_TIME="$2"
      shift 2
      ;;
    -p|--patterns)
      PATTERNS="$2"
      shift 2
      ;;
    *)
      echo "Неизвестный параметр: $1" >&2
      echo "Пожалуйста, используйте ./selectedTimeIntervalErrors_script.sh --help для Справки." >&2
      exit 1
      ;;
  esac
done

# Проверка существования файла лога
if [ ! -f "$LOGFILE" ]; then
  echo "Ошибка: файл $LOGFILE не найден" >&2
  exit 1
fi

# Блок фильтрации по временному диапазону для поиска ошибок
# Если задано и начало и конец временного интервала поиска, то:
if [[ -n "$START_TIME" && -n "$END_TIME" ]]; then
  START_DATE=$(date -d "$START_TIME" "+%b %d %H:%M:%S" 2>/dev/null) || {
    echo "Ошибка: не удалось распознать дату начала '$START_TIME'" >&2; exit 1;
  }
  END_DATE=$(date -d "$END_TIME" "+%b %d %H:%M:%S" 2>/dev/null) || {
    echo "Ошибка: не удалось распознать дату окончания '$END_TIME'" >&2; exit 1;
  }
  awk -v from="$START_DATE" -v to="$END_DATE" '$0 >= from && $0 <= to' "$LOGFILE" \
    | grep -aiE "$PATTERNS" > "$REPORT"

# Если задано только начало временного интервала поиска, то:
elif [[ -n "$START_TIME" ]]; then
  START_DATE=$(date -d "$START_TIME" "+%b %d %H:%M:%S" 2>/dev/null) || {
    echo "Ошибка: не удалось распознать дату начала '$START_TIME'" >&2; exit 1;
  }
  awk -v from="$START_DATE" '$0 >= from' "$LOGFILE" \
    | grep -aiE "$PATTERNS" > "$REPORT"

# Если задан только конец временного интервала поиска, то:
elif [[ -n "$END_TIME" ]]; then
  END_DATE=$(date -d "$END_TIME" "+%b %d %H:%M:%S" 2>/dev/null) || {
    echo "Ошибка: не удалось распознать дату окончания '$END_TIME'" >&2; exit 1;
  }
  awk -v to="$END_DATE" '$0 <= to' "$LOGFILE" \
    | grep -aiE "$PATTERNS" > "$REPORT"
else
  # Если временной интервал не задан, выводятся данные без фильтрации по времени
  grep -aiE "$PATTERNS" "$LOGFILE" > "$REPORT"
fi

# Вывод информации об общем количество строк с ошибками (из заданного временного интервала), а также последние 20 строк с ошибками (также из заданного интервала)
COUNT=$(wc -l < "$REPORT")
echo "Общее количество строк с ошибками (в интервале: ${START_TIME:-с начала файла} — ${END_TIME:-до конца файла}): $COUNT строк в файле $REPORT"
if [[ $COUNT -gt 0 ]]; then
  echo ""
  echo "--- Выводятся последние строки с ошибками, но не более 20 строк. Полный список строк содержится в файле $REPORT ---"
  tail -n 20 "$REPORT"
  echo "-------------------------------------"
else
  echo "Ошибок не найдено"
fi
