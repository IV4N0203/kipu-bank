// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title KipuBank - Bóveda personal con límites de depósito/retiro
/// @author IV4N0203 - AIR.dev
/// @dev Contrato que simula ser bancario para gestionar depósitos y retiros de ETH con límites.
/// @notice Este contrato forma parte del Ethereum Developer Pack Modulo 2
/// @custom:security Este contrato es educativo y no debe usarse en produccion.

contract KipuBank {
    /*///////////
        Variables de Estado
    ///////////*/


    /// @dev Límite máximo global de depósitos (inmutable)
    uint256 public immutable i_bankCap;

    /// @dev Límite máximo por retiro (inmutable)
    uint256 public immutable i_withdrawThreshold;

    /// @dev Deposito total en custodia por KipuBank en ETH
    uint256 private  s_totalAllDeposits;

    /// @dev Saldo de cada usuario en la bóveda
    mapping(address => uint256) private s_balances;

    /// @dev Contador de depósitos totales
    uint256 private s_totalDeposits;

    /// @dev Contador de retiros totales
    uint256 private s_totalWithdrawals;
    
    /*///////////
        Eventos
    ///////////*/

    /// @dev Evento emitido cuando un usuario deposita ETH con exito
    /// @param user Dirección del quien deposita
    /// @param amount Cantidad depositada en wei
    event DepositMade(address indexed user, uint256 amount, uint256 newBalance);
    
    /// @dev Evento emitido cuando un usuario retira ETH con exito
    /// @param user Dirección del quien retira
    /// @param amount Cantidad retirada en wei
    event WithdrawalMade(address indexed user, uint256 amount, uint256 newBalance);

    // ========== Errores Personalizados ==========
    /// @dev Error emitido cuando un depósito excede el límite máximo de capacidad del banco.
    /// @param currentTotal Monto total actual en el banco (incluyendo el depósito intentado).
    /// @param cap Límite máximo de capacidad del banco (definido en "i_bankCap").
    error KipuBank_i_bankCapExceeded(uint256 currentTotal, uint256 cap);
    
    /// @dev Error emitido cuando un retiro supera el umbral máximo permitido por transacción.
    /// @param requested Monto solicitado para retirar.
    /// @param threshold Umbral máximo de retiro por transacción (definido en "withdrawThreshold").
    error KipuBank_WithdrawalThresholdExceeded(uint256 requested, uint256 threshold);
    
    /// @dev Error emitido cuando un usuario intenta retirar más ETH del que tiene disponible en su balance.
    /// @param requested Monto solicitado para retirar.
    /// @param available Balance disponible del usuario en el banco.
    error KipuBank_InsufficientBalance(uint256 requested, uint256 available);
    
    /// @dev Error emitido cuando una transferencia de ETH falla (ej: fallback/receive del destinatario revierte).
    error KipuBank_TransferFailed();
    
    /// @dev Error emitido cuando se proporciona una dirección cero (`address(0)`) donde se espera una dirección válida.
    error KipuBank_ZeroAddress();
    
    /// @dev Error emitido cuando se intenta depositar o retirar un monto de ETH igual a cero.
    error KipuBank_ZeroAmount();

    /*///////////
        Modificadores
    ///////////*/
    
    /// @dev Modificador que verifica si un depósito excedería el límite máximo de capacidad del banco (`i_bankCap`).
    ///      Revierte con `KipuBank_i_bankCapExceeded` si el monto acumulado (`s_totalDeposits + amount`) supera el límite.
    /// @param amount Monto del depósito a validar.

    modifier checki_bankCap(uint256 amount) {
        if (s_totalDeposits + amount > i_bankCap) {
            revert KipuBank_i_bankCapExceeded(s_totalDeposits + amount, i_bankCap);
        }
        _;
    }

    /// @dev Modificador que valida si un retiro supera el umbral máximo permitido por transacción (`i_withdrawThreshold`).
    ///      Revierte con `KipuBank_WithdrawalThresholdExceeded` si el monto solicitado es mayor al umbral configurado.
    /// @param amount Monto del retiro a validar.
    /// @notice Este modificador no verifica el balance del usuario. Usar en conjunto con `checkBalance`.
    modifier checkWithdrawalThreshold(uint256 amount) {
        if (amount > i_withdrawThreshold) {
            revert KipuBank_WithdrawalThresholdExceeded(amount, i_withdrawThreshold);
        }
        _;
    }

    /// @dev Modificador que garantiza que la dirección del llamador (`msg.sender`) no sea la dirección cero (`address(0)`).
    ///      Revierte con `KipuBank_ZeroAddress` si se detecta una dirección inválida.
    modifier nonZeroAddress() {
        if (msg.sender == address(0)) {
            revert KipuBank_ZeroAddress();
        }
        _;
    }
    /*////////
        Constructor
    ////////*/

    /// @dev Constructor que inicializa el contrato con un capital máximo (`i_bankCap`) y un umbral de retiro (`i_withdrawThreshold`).
    ///      Valida que ambos valores sean mayores a cero y que el umbral no supere el capital máximo.
    /// @param _i_bankCap Capital máximo del banco en wei.
    /// @param _i_withdrawThreshold Umbral máximo de retiro por transacción en wei.
    
    constructor(uint256 _i_bankCap, uint256 _i_withdrawThreshold) {
        require(_i_bankCap > 0, "i_bankCap debe ser mayor a 0");
        require(_i_withdrawThreshold > 0, "i_withdrawThreshold debe ser mayor a 0");
        require(_i_withdrawThreshold < _i_bankCap, "i_withdrawThreshold debe ser menor que i_bankCap");

        i_bankCap = _i_bankCap;
        i_withdrawThreshold = _i_withdrawThreshold;
    }

    /*////////
        Funciones Externas
    ////////*/

    /* @dev Función de fallback que permite depositar ETH en el contrato.
          Llamada automáticamente cuando se envía ETH directamente al contrato.
          Utiliza el modificador `nonZeroAddress` para validar la dirección del llamador.
    */
    receive() external payable nonZeroAddress {
        _deposit(msg.sender, msg.value);
    }

    /* @dev Permite a los usuarios depositar ETH en el contrato.
          Valida que el monto sea mayor a cero y utiliza el modificador `nonZeroAddress`
          para asegurar que la dirección del llamador no sea cero.
    */
    function deposit() external payable nonZeroAddress {
        if (msg.value == 0) {
            revert KipuBank_ZeroAmount();
        }
        _deposit(msg.sender, msg.value);
    }

    /*
     @dev Permite a un usuario retirar una cantidad específica de ETH de su balance en el banco.
     @notice Sigue el patrón Checks-Effects-Interactions para prevenir vulnerabilidades de reentrada.
     @param amount Cantidad de ETH a retirar (en wei). Debe ser mayor a 0 y no exceder el balance del usuario ni el umbral de retiro.
     @dev Requiere:
          - El llamador no sea la dirección cero (validado por `nonZeroAddress`).
          - El monto no exceda el umbral máximo de retiro (validado por `checkWithdrawalThreshold`).
          - El monto sea mayor a 0.
          - El usuario tenga saldo suficiente.
     @dev Emite el evento {WithdrawalMade} al finalizar con éxito.
     @dev Revierte con:
         - {KipuBank_ZeroAmount} si el monto es 0.
         - {KipuBank_InsufficientBalance} si el monto excede el balance del usuario.
         - {KipuBank_TransferFailed} si la transferencia de ETH falla.
    */
    function withdraw(uint256 amount) external nonZeroAddress checkWithdrawalThreshold(amount) {
        if (amount == 0) {
            revert KipuBank_ZeroAmount();
        }

        uint256 userBalance = s_balances[msg.sender];
        if (amount > userBalance) {
            revert KipuBank_InsufficientBalance(amount, userBalance);
        }

        // Checks-Effects-Interactions: Actualizar estado ANTES de la transferencia
        s_balances[msg.sender] = userBalance - amount;
        s_totalWithdrawals++;

        // Transferencia segura de ETH 
        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) {
            // Revertir cambios si la transferencia falla
            s_balances[msg.sender] = userBalance;
            revert KipuBank_TransferFailed();
        }

        emit WithdrawalMade(msg.sender, amount, s_balances[msg.sender]);
    }

    /*///////
        funciones de Visualizacion
    ////////*/
    
    /*
        @dev Deposito total en custodia por KipuBank en ETH
        @dev Devuelve el balance actual de ETH del contrato.
        @notice Este valor incluye todos los depósitos de los usuarios menos los retiros realizados.
        @return Balance total del contrato en wei. 
    */
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    /* 
        @dev Devuelve el balance de ETH de un usuario específico en el banco.
        @param user Dirección del usuario cuya balance se quiere consultar.
        @return Balance del usuario a consultar en wei.
        @return Devuelve 0 si el usuario nunca ha realizado depósitos.

    */
    function getUserBalance(address user) external view returns (uint256) {
        return s_balances[user];
    }

    /*
        @dev Devuelve el total acumulado de depósitos realizados en el banco.
        @notice Este valor representa la suma de todos los depósitos históricos,
            sin considerar los retiros (para el balance neto, usar `getContractBalance`).
        @return Total de depósitos en wei.
    */
    function getTotalDeposits() external view returns (uint256) {
        return s_totalDeposits;
    }

    /*
        @dev Devuelve el número total de operaciones de retiro realizadas.
        @notice Este contador se incrementa cada vez que un usuario retira ETH con éxito.
        @return Cantidad total de retiros como entero sin signo.
    */
    function getTotalWithdrawals() external view returns (uint256) {
        return s_totalWithdrawals;
    }

/*/////////
    Funciones Privadas
////////*/

/*
    @dev Función privada que registra un depósito de ETH para un usuario específico.
    @notice Esta función actualiza el balance del usuario y el total de depósitos del banco,
            además de emitir el evento correspondiente.
    @param user Dirección del usuario que realiza el depósito.
    @param amount Cantidad de ETH a depositar (en wei). Debe ser mayor a 0 (validado por el llamador).
    @dev Requiere:
         - Que el depósito no exceda el límite de capacidad del banco (validado por `checki_bankCap`).
         - Que el monto sea válido (mayor a 0, validado por el llamador antes de llamar a esta función).
    @dev Emite el evento {DepositMade} con:
         - La dirección del usuario
         - El monto depositado
         - El nuevo balance del usuario
 
*/
    function _deposit(address user, uint256 amount) private checki_bankCap(amount) {
        s_balances[user] += amount;
        s_totalDeposits += amount;
        emit DepositMade(user, amount, s_balances[user]);
    }
}