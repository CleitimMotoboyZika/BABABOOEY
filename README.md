# 🐵 Arena Selvagem - Roblox Game

Um jogo completo para Roblox com rinha de macacos, corrida de camelos e corrida de lagostins. Os jogadores são observadores que apostam nos resultados e investem seus ganhos para evoluir suas criaturas.

## 🎮 Como Usar

### Opção 1: Abrir direto no Roblox Studio
1. Abra o arquivo `ArenaSelvagem.rbxlx` no Roblox Studio
2. Clique em "Play" para testar
3. Publique no Roblox quando estiver pronto

### Opção 2: Regenerar o arquivo .rbxlx
```bash
python3 generate_rbxlx.py
```
Isso irá gerar o arquivo `ArenaSelvagem.rbxlx` a partir dos scripts Lua em `src/`.

## 🗺️ Mapa - 4 Áreas

| Área | Descrição | Tipo de Jogo |
|------|-----------|-------------|
| 🐫 **Pista do Deserto** | Pista de corrida em um deserto com dunas e palmeiras | Corrida de Camelos |
| 🦞 **Sala dos Aquários** | Sala temática com aquários e mesa de corrida | Corrida de Lagostins |
| 🐵 **Ringue dos Primatas** | Ringue improvisado com cordas e arquibancadas | Rinha de Macacos |
| 🎰 **Sala de Apostas Vintage** | Sala estilo vintage com quadros de odds e lustres | Apostas em todos os jogos |

## ⚙️ Sistemas

### Combate (Estilo Palworld)
- IA controla ambos os lutadores automaticamente
- Sistema turn-based com ataques, defesas, especiais e esquivas
- Stats: HP, ATK, DEF, SPD, CRIT
- Equipamentos dão bônus de stats

### Corridas
- IA controla todos os corredores
- Simulação com velocidade, estamina, aceleração e sorte
- Eventos aleatórios: Speed Burst, Stumble, Second Wind
- 6 corredores por corrida

### Evolução (Estilo Musume)
- 100 níveis de progressão incremental
- Evolução automática nos níveis 30 e 60
- Sistema de afeição (0-100) que dá até 10% de bônus nos stats
- Treinamento com custo em moedas e cooldown de 5 minutos

### Apostas
- Aposta mínima: 10 | Máxima: 10,000
- Payouts: Luta 1.8x (vitória), Corrida 2.5x/1.5x/1.1x (1°/2°/3°)
- 5% de margem da casa

### Trocas P2P
- Troque criaturas e itens com outros jogadores
- Validação server-side de todas as operações
- 2% de taxa em trocas com moedas
- Máximo 6 itens por lado

### Inventário & Equipamentos
- 50 slots de inventário
- Slots de equipamento: Mãos, Corpo, Sela, Acessório
- Compra/venda na loja
- Compatibilidade: Armas/Armaduras → Macacos | Selas → Camelos/Lagostins

## 🐾 Criaturas

### Macacos (8 espécies)
Macaco-Prego, Gorila, Mandril, Orangotango, Macaco-Aranha, Mico-Leão-Dourado, Rei Babuíno, Chimpanzé das Sombras

### Camelos (7 espécies)
Dromedário, Camelo Bactriano, Camelo de Corrida, Vento do Deserto, Tempestade de Areia, Corcova Dourada, Camelo Fantasma

### Lagostins (7 espécies)
Garra Vermelha, Carapaça Azul, Pinça Veloz, Corredor de Coral, Lagostim Elétrico, Lagostim Dourado, Rei Abissal

### Raridades
| Raridade | Peso | Multiplicador |
|----------|------|--------------|
| Comum | 50% | 1.0x |
| Incomum | 30% | 1.2x |
| Raro | 13% | 1.5x |
| Épico | 5% | 2.0x |
| Lendário | 1.8% | 3.0x |
| Mítico | 0.2% | 5.0x |

## 🛡️ Segurança
- **Server-side validation** em todas as operações
- Anti-exploit com caps em moedas, XP, nível e inventário
- Trocas atômicas com rollback em caso de falha
- DataStore com retry logic e backoff exponencial
- Sistema **AutoFix** que monitora e recupera sistemas automaticamente

## 📁 Estrutura do Projeto

```
├── ArenaSelvagem.rbxlx        # Arquivo pronto para Roblox Studio
├── generate_rbxlx.py          # Gerador do .rbxlx
├── src/
│   ├── Server/
│   │   ├── MainServer.lua         # Script principal + AutoFix
│   │   ├── DataStoreManager.lua   # Persistência de dados
│   │   ├── FightSystem.lua        # Sistema de luta IA
│   │   ├── RaceSystem.lua         # Sistema de corrida IA
│   │   ├── TradeSystem.lua        # Sistema de trocas P2P
│   │   ├── EvolutionSystem.lua    # Evolução e treinamento
│   │   └── InventorySystem.lua    # Inventário e equipamentos
│   ├── Client/
│   │   └── ClientMain.lua         # Interface do jogador
│   └── Shared/
│       └── GameConfig.lua         # Configuração compartilhada
└── README.md
```

## 📜 Licença
Projeto original e completo. Todos os direitos reservados.