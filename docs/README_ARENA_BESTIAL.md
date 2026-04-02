# 🐵 Arena Bestial - Roblox Game Project

> Um jogo completo de **Rinha de Macaco**, **Corrida de Camelos** e **Corrida de Lagostins** para Roblox Studio, com estética low-poly pixelada inspirada em Postal: Brain Damaged.

## 🎮 Como Usar

### Importação no Roblox Studio
1. Abra o **Roblox Studio**
2. Vá em **File → Open from File**
3. Selecione o arquivo `ArenaBestial.rbxlx`
4. O jogo está pronto! Clique em **Play** para testar

> **Nenhuma configuração adicional necessária.** Todos os scripts, mapas, UI e sistemas já estão integrados.

---

## 🏗️ Estrutura do Projeto

```
ArenaBestial.rbxlx          ← Arquivo principal (abrir no Roblox Studio)
generate_rbxlx.py           ← Gerador do arquivo .rbxlx
src/
├── server/                  ← Scripts do servidor
│   ├── MainGameServer.lua   ← Orquestrador principal do jogo
│   ├── DataStoreManager.lua ← Sistema de persistência de dados
│   ├── AntiExploit.lua      ← Proteção contra exploits
│   ├── AutoFixSystem.lua    ← Sistema de auto-correção de bugs
│   ├── CombatAIController.lua ← IA de combate de macacos
│   ├── RacingAIController.lua ← IA de corridas
│   ├── BettingManager.lua   ← Sistema de apostas
│   └── TradeManager.lua     ← Sistema de trocas
├── client/                  ← Scripts do cliente
│   └── ClientMain.lua       ← UI, câmera e interação
└── shared/                  ← Módulos compartilhados
    ├── GameConfig.lua       ← Configuração central do jogo
    └── MapData.lua          ← Dados de geometria do mapa
```

---

## 🌍 Mapa - 4 Áreas

### 🏜️ Pista de Corrida no Deserto
- Pista oval com cercas de madeira
- Dunas de areia decorativas
- Cactos low-poly
- Arquibancada para espectadores
- Placar digital

### 🦞 Sala do Aquário
- Sala fechada com paredes de vidro estilo aquário
- Mesa de corrida com 5 pistas neon
- Decorações de coral e algas marinhas
- Baú do tesouro decorativo
- Bancos para espectadores

### 🐵 Ringue de Macacos
- Ring elevado com tapete
- 4 postes de metal com cordas vermelhas
- Arquibancadas ao redor
- Iluminação de holofotes
- Barris decorativos

### 🎰 Sala de Apostas Vintage
- Piso de madeira escura
- Balcão de apostas com tampo verde
- Quadros-negros de odds
- TVs CRT mostrando corridas
- Mesas redondas de pub com bancos
- Luminárias pendentes
- Pôsteres de corrida de cavalos
- Caixa registradora vintage
- Carpete verde

---

## 🐒 Criaturas

### Macacos (Combate)
| Nome | Raridade | HP Base | Ataque | Defesa | Velocidade |
|------|----------|---------|--------|--------|------------|
| Capuchin | Common | 100 | 15 | 10 | 12 |
| Howler Monkey | Common | 130 | 18 | 8 | 10 |
| Spider Monkey | Uncommon | 90 | 20 | 7 | 18 |
| Mandrill | Rare | 160 | 25 | 15 | 8 |
| Golden Lion Tamarin | Rare | 80 | 22 | 6 | 20 |
| Silverback Gorilla | Epic | 250 | 35 | 25 | 5 |
| Shadow Chimpanzee | Epic | 140 | 30 | 12 | 16 |
| Inferno Baboon | Legendary | 200 | 40 | 18 | 12 |
| Cosmic Orangutan | Legendary | 300 | 45 | 30 | 10 |
| **Void Ape** | **Mythic** | **350** | **55** | **35** | **14** |

### Camelos (Corrida no Deserto)
| Nome | Raridade | Velocidade | Stamina | Aceleração |
|------|----------|------------|---------|------------|
| Dromedary | Common | 10 | 100 | 5 |
| Bactrian Camel | Common | 9 | 130 | 4 |
| Sand Sprinter | Uncommon | 14 | 80 | 8 |
| Dune Runner | Rare | 12 | 110 | 7 |
| Golden Hump | Epic | 16 | 120 | 9 |
| Phantom Camel | Legendary | 20 | 100 | 12 |
| **Celestial Dromedary** | **Mythic** | **25** | **150** | **15** |

### Lagostins (Corrida no Aquário)
| Nome | Raridade | Velocidade | Stamina | Aceleração |
|------|----------|------------|---------|------------|
| American Lobster | Common | 8 | 100 | 4 |
| Blue Lobster | Uncommon | 10 | 90 | 6 |
| Rock Lobster | Common | 7 | 140 | 3 |
| Mantis Shrimp | Rare | 15 | 70 | 10 |
| Golden Claw Lobster | Epic | 13 | 110 | 8 |
| Abyssal Lobster | Legendary | 18 | 120 | 11 |
| **Kraken Spawn** | **Mythic** | **22** | **150** | **14** |

### Sistema de Raridade
- **Common** (50%) - Multiplicador: 1.0x
- **Uncommon** (25%) - Multiplicador: 1.25x
- **Rare** (15%) - Multiplicador: 1.5x
- **Epic** (7%) - Multiplicador: 2.0x
- **Legendary** (2.5%) - Multiplicador: 3.0x
- **Mythic** (0.5%) - Multiplicador: 5.0x

---

## ⚔️ Sistema de Combate

- **Controlado 100% por IA** - O jogador é apenas observador
- Cada macaco tem personalidade aleatória (Agressão/Cautela)
- Sistema de movimentos com cooldown
- Golpes críticos, buffs, debuffs
- Escudo, evasão, invisibilidade
- Dano calculado com ataque vs defesa + variação aleatória
- Máximo de 20 rounds por luta
- Decisão por HP% se o tempo acabar

### Movimentos Especiais
- **Void Strike** (55 dano) - Mythic
- **Oblivion** (70 dano) - Mythic
- **Dimensional Rift** (40 dano, ignora defesa) - Mythic
- **Cosmic Punch** (38 dano) - Legendary
- **Fire Punch** (32 dano) - Legendary
- E mais 20+ movimentos únicos!

---

## 🏇 Sistema de Corrida

- **IA independente para cada corredor**
- Sistema de stamina com gestão inteligente
- Eventos aleatórios: bursts de velocidade, tropeços, sorte
- Personalidade de corrida (conservador vs agressivo)
- NPCs preenchem vagas vazias automaticamente
- Snapshots para replay visual

---

## 💰 Sistema de Apostas

- Aposta mínima: $10 | Máxima: $10,000
- Multiplicador de payout: 2.5x
- Odds dinâmicas baseadas nas apostas
- Pool de apostas compartilhado
- Uma aposta por jogador por evento
- Validação completa server-side

---

## 📦 Inventário & Equipamento

### Slots de Equipamento
- **Macacos**: Cabeça, Corpo, Mãos
- **Camelos**: Corpo, Pés
- **Lagostins**: Corpo, Cauda

### Exemplos de Equipamento
| Item | Tipo | Slot | Bônus | Raridade | Preço |
|------|------|------|-------|----------|-------|
| Leather Gloves | Monkey | Hands | ATK+3, DEF+1 | Common | $100 |
| Iron Knuckles | Monkey | Hands | ATK+8, DEF+2, SPD-1 | Uncommon | $300 |
| Champion Belt | Monkey | Body | ATK+5, DEF+5, SPD+2 | Rare | $800 |
| Void Gauntlets | Monkey | Hands | ATK+20, DEF+10, SPD+5 | Legendary | $5000 |
| Racing Saddle | Camel | Body | SPD+5, STA+20 | Rare | $700 |
| Turbo Tail | Lobster | Tail | SPD+6, STA-5 | Rare | $500 |
| Golden Shell | Lobster | Body | SPD+8, STA+20 | Legendary | $4000 |

---

## 📈 Evolução & Treinamento

- **Level máximo**: 100
- **XP incremental**: Base 100, escala 15% por nível
- **Treinamento pago**: Custo escala com o nível
- **Ganhos por nível** (Macacos): HP+5, ATK+2, DEF+1, SPD+1
- **Ganhos por nível** (Corrida): SPD+0.5, STA+2, ACC+0.3
- **Milestones visuais**: Níveis 10, 25, 50, 75, 100
- XP ganha assistindo eventos com criatura ativa

---

## 🔄 Sistema de Trocas

- Troca de criaturas, equipamentos e dinheiro
- Taxa de 5% sobre dinheiro trocado
- Confirmação dupla (ambos jogadores)
- Validação server-side de todos os itens
- Cancelamento automático se jogador sair
- Timeout de 60 segundos para aceitar

---

## 🔒 Segurança

### Anti-Exploit
- Rate limiting: máximo 10 requests/segundo
- Detecção de atividade suspeita (5 flags = ban temporário)
- Validação de todas as transações monetárias
- Ban temporário de 1 hora
- Verificação de integridade de itens em trocas

### Server-Side Validation
- **Todas** as operações de dados são feitas no servidor
- Clientes só enviam requests, nunca modificam dados
- Verificação de saldo antes de compras/apostas
- Validação de tipo e existência de itens

### Auto-Fix System
- Executa diagnósticos a cada 30 segundos
- Verifica e recria RemoteEvents faltantes
- Corrige dados corrompidos de jogadores
- Repara valores inválidos (NaN, negativos)
- Limpa instâncias órfãs
- Regenera objetos de spawn se removidos
- Log de todas as correções aplicadas

---

## ⌨️ Controles

| Tecla | Ação |
|-------|------|
| **I** | Abrir/Fechar Inventário |
| **B** | Abrir/Fechar Apostas |
| **T** | Abrir/Fechar Trocas |
| **E** | Abrir/Fechar Evolução/Treinamento |
| **P** | Abrir/Fechar Loja |

---

## 🎨 Estilo Visual

- **Low-poly pixelado** inspirado em Postal: Brain Damaged
- Fonte monospace (Code) para visual pixelado
- Paleta de cores escuras com destaques neon
- UI com bordas pixeladas e fundo escuro
- Atmosfera com haze para efeito de deserto
- Correção de cor com contraste aumentado e saturação reduzida

---

## 🔧 Regeneração do Projeto

Se precisar regenerar o arquivo .rbxlx após editar os scripts Lua:

```bash
python3 generate_rbxlx.py
```

Isso vai ler todos os arquivos em `src/` e gerar um novo `ArenaBestial.rbxlx`.

---

## 📋 Starter Pack (Novos Jogadores)

Todo jogador novo recebe:
- 💰 $500 de dinheiro inicial
- 🐵 1 Capuchin (macaco)
- 🐪 1 Dromedary (camelo)
- 🦞 1 American Lobster (lagostim)
- 🧤 Leather Gloves + Fighter Vest + Basic Saddle + Shell Polish

---

## 📊 Estatísticas Rastreadas

- Total de apostas feitas/ganhas
- Total de dinheiro ganho/perdido
- Total de lutas assistidas
- Total de corridas assistidas
- Total de trocas completadas
- Tempo total de jogo
- Data de criação da conta

---

*Arena Bestial © 2026 - Projeto Original*
