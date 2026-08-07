#!/bin/sh
# Synchronise le dossier local avec GitHub au démarrage d'une session.
#
# Un pull avalé en silence est le pire des cas : la session travaillerait sur un
# état périmé sans que personne le sache, et le conflit n'apparaîtrait qu'au
# moment de pousser. Donc si l'avance rapide est impossible, on le dit, avec de
# quoi comprendre pourquoi (commits locaux non poussés, ou fichiers modifiés).

cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

BEFORE=$(git rev-parse HEAD 2>/dev/null)

if OUT=$(git pull --ff-only 2>&1); then
  AFTER=$(git rev-parse HEAD 2>/dev/null)
  [ "$BEFORE" = "$AFTER" ] && exit 0
  N=$(git log "$BEFORE..$AFTER" --oneline 2>/dev/null | wc -l | tr -d ' ')
  printf '{"systemMessage": "Synchronisé avec GitHub : %s commit(s) récupéré(s) depuis la dernière session."}\n' "$N"
  exit 0
fi

AHEAD=$(git log @{u}.. --oneline 2>/dev/null | wc -l | tr -d ' ')
DIRTY=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
# git commence par le compte rendu du fetch ; la vraie cause est plus bas.
MSG=$(printf '%s\n' "$OUT" | grep -E '^(error|fatal):' | head -2)
[ -z "$MSG" ] && MSG=$(printf '%s\n' "$OUT" | grep -E '^hint:' | head -1)
[ -z "$MSG" ] && MSG=$OUT
# Le message part dans du JSON : on retire guillemets et antislashs, et on met
# la sortie de git sur une seule ligne.
REASON=$(printf '%s' "$MSG" | tr -d '"\\' | tr '\n' ' ' | cut -c1-180)

printf '{"systemMessage": "ATTENTION : git pull a échoué, le dossier local ne correspond pas à GitHub. Commits locaux non poussés : %s. Fichiers modifiés non validés : %s. Détail : %s"}\n' "$AHEAD" "$DIRTY" "$REASON"
