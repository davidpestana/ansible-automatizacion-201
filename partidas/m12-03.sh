# M12-03: prod con el portal instalado (site.yml) y el workflow de validación del lab 01
# en .github/workflows/validar.yml de la raíz del repo (solo si no existe).
ansible-playbook -i inventories/prod/hosts.yml site.yml | sed -n '/PLAY RECAP/,$p'
if [ ! -f ../.github/workflows/validar.yml ]; then
  mkdir -p ../.github/workflows
  cat > ../.github/workflows/validar.yml <<'YAML'
# .github/workflows/validar.yml
name: Validar proyecto Ansible

on:
  pull_request:
    branches: [main]
    paths:
      - "proyecto/**"
      - ".github/workflows/validar.yml"
  push:
    branches: [main]
    paths:
      - "proyecto/**"
      - ".github/workflows/validar.yml"

permissions:
  contents: read

jobs:
  validar:
    name: Lint, syntax, site y check en pre
    runs-on: ubuntu-24.04
    env:
      ANSIBLE_FORCE_COLOR: "1"
    steps:
      - name: Descargar el repositorio
        uses: actions/checkout@v4

      - name: Preparar Python 3.12
        uses: actions/setup-python@v5
        with:
          python-version: "3.12"
          cache: pip

      - name: Instalar Ansible y ansible-lint
        run: pip install -r requirements.txt

      - name: Levantar los nodos de prueba
        run: bash scripts/nodos.sh up

      - name: Lint y syntax-check
        working-directory: proyecto
        run: make validar

      - name: Aplicar site.yml en pre
        working-directory: proyecto
        run: make site ENTORNO=pre

      - name: Simular en pre (check)
        working-directory: proyecto
        run: make check ENTORNO=pre
YAML
  echo "Creado .github/workflows/validar.yml"
fi
