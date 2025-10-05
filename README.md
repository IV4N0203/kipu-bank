# KipuBank - IVAN ALARCON 
**Bóveda Personal con Límites de Depósito/Retiro en Ethereum**

---

## 📜 Descripción
**KipuBank** es un contrato educativo que simula un **banco descentralizado** con las siguientes características:
- **Límite global de depósitos** (`i_bankCap`): Máximo de ETH que el contrato puede manejar.
- **Umbral de retiro** (`i_withdrawThreshold`): Límite máximo por transacción de retiro.
- **Seguimiento de balances**: Cada usuario tiene un saldo individual.
- **Eventos detallados**: Registra depósitos y retiros con balances actualizados.
- **Mecanismos de seguridad**:
  - Prevención de reentrada (patrón *Checks-Effects-Interactions*).
  - Validación de direcciones (`address(0)`).
  - Manejo de transferencias fallidas.
  - Errores personalizados descriptivos.

⚠️ **Advertencia**: Este contrato es **solo para fines educativos** (parte del *Ethereum Developer Pack Módulo 2*). **No usar en producción** sin una auditoría de seguridad.

---

## 🛠 Requisitos Previos
- **MetaMask** ([Instalar aquí](https://metamask.io/)) con fondos en **Sepolia Testnet**.
- **Remix IDE** ([https://remix.ethereum.org/](https://remix.ethereum.org/)) o **Hardhat/Foundry** para despliegue local.
- **Sepolia ETH**: Obtén tokens de prueba en [Sepolia Faucet](https://sepoliafaucet.com/).
- **Navegador**: Chrome, Brave o Firefox (con MetaMask instalado).

---

## 🚀 Despliegue en Sepolia (usando Remix + MetaMask)

### **Paso 1: Configurar MetaMask para Sepolia**
1. Abre MetaMask y haz clic en la red actual (ej: "Ethereum Mainnet").
2. Selecciona **"Add network"** > **"Add a network manually"**.
3. Ingresa los siguientes datos:
   - **Network Name**: `Sepolia Testnet`
   - **New RPC URL**: `https://rpc.sepolia.dev` (o usa Infura: `https://sepolia.infura.io/v3/TU_API_KEY`)
   - **Chain ID**: `11155111`
   - **Currency Symbol**: `ETH`
   - **Block Explorer URL**: `https://sepolia.etherscan.io`
4. Guarda la red.
5. **Obtén ETH de prueba**:
   - Copia tu dirección de MetaMask.
   - Pégala en un faucet como [Sepolia Faucet](https://sepoliafaucet.com/) y solicita fondos.

### **Paso 2: Compilar en Remix**
1. Abre [Remix IDE](https://remix.ethereum.org/).
2. Crea un nuevo archivo llamado `KipuBank.sol` en la carpeta `contracts/` y pega el código del contrato.
3. Ve a la pestaña **"Solidity Compiler"** (icono de compilador).
4. Selecciona la versión **0.8.26** y haz clic en **"Compile KipuBank.sol"**.

### **Paso 3: Desplegar el Contrato**
1. Ve a la pestaña **"Deploy & Run Transactions"** (icono de Ethereum).
2. En **"ENVIRONMENT"**, selecciona **"Injected Provider - MetaMask"** (se abrirá una ventana para conectar tu wallet).
3. **Parámetros del constructor**:
   - `_i_bankCap`: Límite máximo del banco (ej: `1000000000000000000` = **1 ETH** en wei).
   - `_i_withdrawThreshold`: Umbral de retiro (ej: `100000000000000000` = **0.1 ETH** en wei).
4. Haz clic en **"Deploy"**.
5. **Confirma la transacción en MetaMask** (gas fee ~0.0005 ETH).
6. **Verifica el despliegue**:
   - El contrato aparecerá en la sección **"Deployed Contracts"** en Remix.
   - Copia la dirección del contrato y búscalo en [Sepolia Etherscan](https://sepolia.etherscan.io/).

---

## 🤝 Interacción con el Contrato

### **1. Depositar ETH**
**Métodos disponibles**:
- **`deposit()`**: Función explícita para depositar ETH.
- **Fallback (`receive()`)**: Envía ETH directamente a la dirección del contrato.

**Pasos (usando Remix)**:
1. En la sección **"Deployed Contracts"**, selecciona tu instancia de `KipuBank`.
2. **Opción 1 (deposit)**:
   - En el campo **"VALUE"**, ingresa el monto en ETH (ej: `0.5`).
   - Haz clic en el botón **`deposit`**.
   - Confirma en MetaMask.
3. **Opción 2 (fallback)**:
   - Envía ETH directamente desde MetaMask a la dirección del contrato.
4. **Verifica el evento**:
   - En Remix, haz clic en el icono de **logs** (abajo a la derecha) para ver el evento `DepositMade`.

### **2. Retirar ETH**
1. En Remix, en el contrato desplegado, ingresa el monto a retirar (en wei) en el campo de `withdraw` (ej: `100000000000000000` = 0.1 ETH).
2. Haz clic en **`withdraw`**.
3. Confirma la transacción en MetaMask.
4. **Verifica**:
   - Tu balance en MetaMask debería aumentar.
   - Revisa los logs en Remix para el evento `WithdrawalMade`.

### **3. Funciones de Lectura (View)**
Puedes llamar a estas funciones **sin gas** para consultar datos:
| Función                  | Descripción                                                                 |
|--------------------------|-----------------------------------------------------------------------------|
| `getContractBalance()`   | Balance total de ETH en el contrato (depósitos - retiros).                |
| `getUserBalance(user)`   | Balance de un usuario específico (ingresa tu dirección).                   |
| `getTotalDeposits()`     | Suma histórica de todos los depósitos (sin restar retiros).               |
| `getTotalWithdrawals()`  | Número total de retiros realizados.                                        |

**Ejemplo (en Remix)**:
1. Llama a `getUserBalance` con tu dirección como parámetro.
2. El resultado mostrará tu saldo en wei.

### **4. Pruebas de Errores**
Para validar los mecanismos de seguridad, intenta las siguientes acciones y verifica los errores:
| Acción                                  | Error Esperado                          | Descripción                                  |
|-----------------------------------------|-----------------------------------------|----------------------------------------------|
| Depositar 0 ETH                         | `KipuBank_ZeroAmount`                   | Monto debe ser > 0.                          |
| Retirar más que el umbral (ej: 0.2 ETH) | `KipuBank_WithdrawalThresholdExceeded` | Umbral configurado en 0.1 ETH.               |
| Retirar más que tu balance              | `KipuBank_InsufficientBalance`          | Fondos insuficientes.                        |
| Depositar desde `address(0)`            | `KipuBank_ZeroAddress`                  | Dirección inválida.                         |
| Exceder el límite global del banco      | `KipuBank_i_bankCapExceeded`            | Ej: Si el límite es 1 ETH y ya hay 1 ETH.    |

---

## 🔍 Verificación en Etherscan (Opcional)
1. Ve a [Sepolia Etherscan](https://sepolia.etherscan.io/).
2. Pega la dirección del contrato desplegado.
3. En la pestaña **"Contract"**, podrás:
   - Leer las variables públicas (`i_bankCap`, `i_withdrawThreshold`).
   - Interactuar con las funciones `view` (sin gas).
   - Verificar el código fuente (si lo subes).

---

### **Seguridad**
- **No uses este contrato en Mainnet**: Está diseñado para aprendizaje y no ha sido auditado.
- **Patrón Checks-Effects-Interactions**: El contrato sigue este patrón para evitar vulnerabilidades de reentrada.
- **Transferencias seguras**: Usa `call` en lugar de `transfer` para manejar fallos (ej: contratos que revierten en `receive`).

---

## 📄 Licencia
Este proyecto está bajo la licencia **MIT**. Consulta el archivo [LICENSE](LICENSE) para más detalles.

---
✅ **¡Listo!** Ahora puedes desplegar, interactuar y probar **KipuBank** en Sepolia.
```---
