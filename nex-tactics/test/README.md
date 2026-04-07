# Testes do Warcrown

Esta pasta concentra os testes automatizados do projeto usando `GUT`.

## Convencao atual

- Colocar testes em `res://test/`
- Agrupar por dominio em subpastas como `core/`
- Nomear arquivos como `test_*.gd`
- Usar `extends GutTest`

## Execucao

No editor:

- abrir `Project > Tools > GUT`
- rodar os testes em `res://test`

Via linha de comando:

```powershell
godot4 --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit
```

## Cobertura inicial

- carregamento de decks
- carregamento de unidades e cartas
- regras da loja a cada 3 rodadas
- dano pos-combate
- regras basicas de economia
