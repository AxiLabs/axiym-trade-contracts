// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.24;

import {LinkedList} from "../trade/LinkedList.sol";

/// @title LinkedListTest
/// @notice Minimal test contract that inherits LinkedList directly.
/// @dev Exposes internal mutating functions externally for testing purposes.
contract LinkedListTest is LinkedList {
    // ========================
    // 🟦 Internal Conversion
    // ========================

    function testToUint(bytes16 tradeBytes) external view returns (uint256) {
        return _toUint(tradeBytes);
    }

    function testToBytes(uint256 tradeUint) external view returns (bytes16) {
        return _toBytes(tradeUint);
    }

    function testRegisterTrade(uint256 tradeUint, bytes16 tradeBytes) external {
        _registerTrade(tradeUint, tradeBytes);
    }

    function testUnregisterTrade(uint256 tradeUint) external {
        _unregisterTrade(tradeUint);
    }

    // ========================
    // 🟦 Existence Checks
    // ========================

    function testTradeExists(uint256 trade) external view returns (bool) {
        return tradeExists(trade);
    }

    function testTradeExistsBytes(bytes16 tradeBytes) external view returns (bool) {
        return tradeExistsBytes(tradeBytes);
    }

    function testListExists() external view returns (bool) {
        return listExists();
    }

    // ========================
    // 🟦 Insertion Helpers
    // ========================

    function testInsertAfter(
        uint256 existing,
        uint256 trade
    ) external returns (bool) {
        return _insertAfter(existing, trade);
    }

    function testInsertAfterBytes(
        bytes16 existingBytes,
        bytes16 tradeBytes
    ) external returns (bool) {
        return _insertAfterBytes(existingBytes, tradeBytes);
    }

    function testInsertBefore(
        uint256 existing,
        uint256 trade
    ) external returns (bool) {
        return _insertBefore(existing, trade);
    }

    function testInsertBeforeBytes(
        bytes16 existingBytes,
        bytes16 tradeBytes
    ) external returns (bool) {
        return _insertBeforeBytes(existingBytes, tradeBytes);
    }

    function testInsert(
        uint256 existing,
        uint256 trade,
        bool direction
    ) external returns (bool) {
        return _insert(existing, trade, direction);
    }

    // ========================
    // 🟦 Push Helpers
    // ========================

    function testPushHead(uint256 trade) external returns (bool) {
        return _pushHead(trade);
    }

    function testPushHeadBytes(bytes16 tradeBytes) external returns (bool) {
        return _pushHeadBytes(tradeBytes);
    }

    function testPushTail(uint256 trade) external returns (bool) {
        return _pushTail(trade);
    }

    function testPushTailBytes(bytes16 tradeBytes) external returns (bool) {
        return _pushTailBytes(tradeBytes);
    }

    // ========================
    // 🟦 Removal Helpers
    // ========================

    function testPopHead() external returns (uint256) {
        return _popHead();
    }

    function testPopHeadBytes() external returns (bytes16) {
        return _popHeadBytes();
    }

    function testPopTail() external returns (uint256) {
        return _popTail();
    }

    function testPopTailBytes() external returns (bytes16) {
        return _popTailBytes();
    }

    function testRemove(uint256 trade) external returns (uint256) {
        return _remove(trade);
    }

    function testRemoveBytes(bytes16 tradeBytes) external returns (bytes16) {
        return _removeBytes(tradeBytes);
    }

    // ========================
    // 🟦 Move Helpers
    // ========================

    function testMove(
        uint256 trade,
        uint256 target,
        bool direction
    ) external returns (bool) {
        return _move(trade, target, direction);
    }

    function testMoveBytes(
        bytes16 tradeBytes,
        bytes16 targetBytes,
        bool direction
    ) external returns (bool) {
        return _moveBytes(tradeBytes, targetBytes, direction);
    }

    // ========================
    // 🟦 Linking Helpers
    // ========================

    function testLinkTrades(
        uint256 existing,
        uint256 adjacent,
        bool direction
    ) external {
        _linkTrades(existing, adjacent, direction);
    }

    // ========================
    // 🟦 Getters
    // ========================

    function testGetTrade(
        uint256 trade
    ) external view returns (bool, uint256, uint256) {
        return getTrade(trade);
    }

    function testGetTradeBytes(
        bytes16 tradeBytes
    ) external view returns (bool, bytes16, bytes16) {
        return getTradeBytes(tradeBytes);
    }

    function testGetAdjacent(
        uint256 trade,
        bool direction
    ) external view returns (bool, uint256) {
        return getAdjacent(trade, direction);
    }

    function testGetAdjacentBytes(
        bytes16 tradeBytes,
        bool direction
    ) external view returns (bool, bytes16) {
        return getAdjacentBytes(tradeBytes, direction);
    }

    function testGetNext(uint256 trade) external view returns (bool, uint256) {
        return getNext(trade);
    }

    function testGetNextBytes(
        bytes16 tradeBytes
    ) external view returns (bool, bytes16) {
        return getNextBytes(tradeBytes);
    }

    function testGetPrev(uint256 trade) external view returns (bool, uint256) {
        return getPrev(trade);
    }

    function testGetPrevBytes(
        bytes16 tradeBytes
    ) external view returns (bool, bytes16) {
        return getPrevBytes(tradeBytes);
    }

    function testGetTradeBookSize() external view returns (uint256) {
        return getTradeBookSize();
    }

    // ========================
    // 🟦 Conversion Getters
    // ========================

    function testGetTradeUintFromBytes(
        bytes16 tradeBytes
    ) external view returns (uint256) {
        return getTradeUintFromBytes(tradeBytes);
    }

    function testGetTradeBytesFromUint(
        uint256 tradeUint
    ) external view returns (bytes16) {
        return getTradeBytesFromUint(tradeUint);
    }

    function testTradeBytesMappingExists(
        bytes16 tradeBytes
    ) external view returns (bool) {
        return tradeBytesMappingExists(tradeBytes);
    }

    function testTradeUintMappingExists(
        uint256 tradeUint
    ) external view returns (bool) {
        return tradeUintMappingExists(tradeUint);
    }
}
