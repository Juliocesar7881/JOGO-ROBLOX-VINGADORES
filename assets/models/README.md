# Arte final (modelos do Studio)

Os heróis, inimigos e chefes do jogo são gerados por código enquanto a arte
final não existe. Quando um modelo definitivo fica pronto no Studio, ele entra
por esta pasta e passa a ser usado **automaticamente**. Não é preciso mudar
código.

- **Heróis:** torre, prévia de posicionamento, retratos e Campo de Treino.
- **Inimigos e chefes:** o modelo do inimigo em campo.

A arte muda só a aparência. Alcance, colisão, dano e regras continuam no
servidor, exatamente iguais.

## Passo a passo

1. **No Studio:** monte o modelo como um único `Model` (veja o contrato
   abaixo).
2. **Exportar:** clique com o botão direito no Model → **Save to File…** →
   escolha o formato **`.rbxmx`** (XML; o `.rbxm` binário não é aceito).
3. **Salvar na pasta:** o nome do arquivo é o id do personagem:
   - heróis em `assets/models/heroes/<id>.rbxmx` (ex.: `heroes/ironman.rbxmx`);
   - inimigos e chefes em `assets/models/enemies/<id>.rbxmx` (ex.:
     `enemies/zombie.rbxmx`, `enemies/lizard.rbxmx`).
   Os ids estão em `src/shared/Catalog.luau` (`HeroOrder`, `EnemyOrder`,
   `BossOrder`). Um modelo de família (`enemies/brute.rbxmx`) vale também
   para as variantes regionais dessa família que não tiverem modelo próprio.
4. **Registrar no manifesto:** adicione a entrada em `manifest.json` com
   **autor** e **permissão de uso**:
   ```json
   "heroes": {
     "ironman": { "file": "heroes/ironman.rbxmx", "author": "Voidhb8", "permission": "trabalho próprio" }
   }
   ```
5. **Testar e publicar:** rode `python tools/test.py` e faça o commit. O build
   coloca o modelo em `ReplicatedStorage.DoomArt` de todos os lugares.

O build **recusa** o arquivo em três casos: sem entrada no manifesto, sem autor
ou permissão, e com qualquer `Script`, `LocalScript` ou `ModuleScript` dentro.
Arte nunca executa código.

## Contrato do modelo

- **Um único `Model`**, com `PrimaryPart` definido.
- **Frente para -Z:** a frente do personagem olha para o `LookVector` do pivô.
- **Pivô no centro dos pés:** use a ferramenta *Pivot* do Studio. O jogo
  apoia o pivô sobre o pedestal da torre (heróis) ou sobre a rua (inimigos).
- **Tamanho:** o humanoide comum tem cerca de 6 studs. Hulk fica entre 10 e
  11, Rocket com cerca de 60% da altura humana e Groot alto e estreito. A
  torre acrescenta só o destaque habitual de 15%.
- **Ponto de disparo:** um `Attachment` chamado `Muzzle` onde o tiro deve
  sair (na mão, no arco, no canhão). Sem ele, o tiro sai do centro da torre.
- **Cabeça:** uma parte chamada `Head` recebe o nome flutuante do herói.
- **Animações (opcional):** coloque um `AnimationController` com `Animator`
  (ou um `Humanoid`) e uma rig com `Motor6D`. Guarde os ids publicados como
  atributos numéricos no `Model`:
  - heróis: `IdleAnimation`, `AttackAnimation`, `AbilityAnimation` e
    `UpgradeAnimation`;
  - inimigos: `WalkAnimation`.

  Sem animações, o herói ainda gira para o alvo e pula ao ser melhorado.
- **Materiais e texturas:** só próprios ou licenciados. Nada da Toolbox sem
  licença registrada no manifesto.
- **Desempenho:** mantenha inimigos leves. Podem existir 180 ao mesmo tempo
  em campo.

## O que não vem daqui

Retratos 2D, ícones e sons seguem os caminhos próprios deles. Os sons ficam em
`assets/audio` e os IDs em `deployment/local.json`.
