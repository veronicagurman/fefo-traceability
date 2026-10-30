#!/bin/zsh

PROJECT="$HOME/Documents/fefo-traceability"
APP="$PROJECT/FEFO Traceability.app"

if ! curl -fsS "http://127.0.0.1:8080/api/health" >/dev/null 2>&1; then
    echo "Сначала запусти сервер в отдельном окне Terminal:"
    echo "cd ~/Documents/fefo-traceability/server"
    echo "swift run"
    exit 1
fi

open "$APP"
