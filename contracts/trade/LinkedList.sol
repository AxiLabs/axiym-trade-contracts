// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.24;

/// @title LinkedList
/// @notice Contract implementing a circular doubly linked list for trade management.
abstract contract LinkedList {
    /// @notice Total size of the list.
    uint256 internal size;

    /// @notice Mapping of trade ID to its adjacent trades.
    mapping(uint256 => mapping(bool => uint256)) internal trades;
    mapping(bytes16 => uint256) internal _tradesBytesToUint;
    mapping(uint256 => bytes16) internal _tradesUintToBytes;

    uint256 internal constant NULL = 0;
    uint256 internal constant HEAD = 0;
    bytes16 internal constant NULLBYTES = bytes16(0);
    bytes16 internal constant HEADBYTES = bytes16(0);
    bool internal constant PREV = false;
    bool internal constant NEXT = true;

    // ========================
    // 🟦 Internal Conversion
    // ========================

    /// @notice Converts bytes16 trade ID to uint256 internally
    /// @param _tradeBytes The bytes16 trade ID
    /// @return uint256 representation
    function _toUint(bytes16 _tradeBytes) internal view returns (uint256) {
        if (_tradeBytes == NULLBYTES) return NULL;
        return _tradesBytesToUint[_tradeBytes];
    }

    /// @notice Converts uint256 trade ID to bytes16 internally
    /// @param _tradeUint The uint256 trade ID
    /// @return bytes16 representation
    function _toBytes(uint256 _tradeUint) internal view returns (bytes16) {
        if (_tradeUint == 0) return NULLBYTES;
        return _tradesUintToBytes[_tradeUint];
    }

    /// @notice Registers a trade mapping between uint256 and bytes16
    /// @param _tradeUint The uint256 trade ID
    /// @param _tradeBytes The bytes16 trade ID
    function _registerTrade(uint256 _tradeUint, bytes16 _tradeBytes) internal {
        if (_tradeUint == NULL || _tradeBytes == NULLBYTES) revert("NULLENTRY");
        require(
            _tradesBytesToUint[_tradeBytes] == 0 &&
                _tradesUintToBytes[_tradeUint] == bytes16(0),
            "MappingExists"
        );
        _tradesUintToBytes[_tradeUint] = _tradeBytes;
        _tradesBytesToUint[_tradeBytes] = _tradeUint;
    }

    /// @notice Unregisters a trade mapping
    /// @param _tradeUint The uint256 trade ID to unregister
    function _unregisterTrade(uint256 _tradeUint) internal {
        if (_tradeUint == NULL) revert("NULLENTRY");
        bytes16 tradeBytes = _tradesUintToBytes[_tradeUint];
        delete _tradesUintToBytes[_tradeUint];
        delete _tradesBytesToUint[tradeBytes];
    }

    // ========================
    // 🟦 Existence Checks
    // ========================

    /// @notice Checks if an trade exists in the list.
    /// @param _trade The trade ID to check.
    /// @return True if the trade exists, false otherwise.
    function tradeExists(uint256 _trade) public view returns (bool) {
        if (trades[_trade][PREV] == HEAD && trades[_trade][NEXT] == HEAD) {
            return (trades[HEAD][NEXT] == _trade);
        } else {
            return true;
        }
    }

    /// @notice Checks if a bytes16 trade exists in the list.
    /// @param _tradeBytes The bytes16 trade ID to check.
    /// @return True if the trade exists, false otherwise.
    function tradeExistsBytes(bytes16 _tradeBytes) public view returns (bool) {
        return tradeExists(_toUint(_tradeBytes));
    }

    /// @notice Checks if the list contains any trades.
    /// @return True if the list has at least one trade.
    function listExists() public view returns (bool) {
        return (trades[HEAD][PREV] != HEAD || trades[HEAD][NEXT] != HEAD);
    }

    // ========================
    // 🟦 Insertion Helpers
    // ========================

    /// @notice Inserts a new trade after an existing trade.
    /// @param _existingTrade The existing trade to insert after.
    /// @param _newTrade The new trade to insert.
    /// @return True if insertion succeeded.
    function _insertAfter(
        uint256 _existingTrade,
        uint256 _newTrade
    ) internal virtual returns (bool) {
        return _insert(_existingTrade, _newTrade, NEXT);
    }

    /// @notice Inserts a new bytes16 trade after an existing bytes16 trade.
    /// @param _existingTradeBytes The existing trade to insert after.
    /// @param _newTradeBytes The new trade to insert.
    /// @return True if insertion succeeded.
    function _insertAfterBytes(
        bytes16 _existingTradeBytes,
        bytes16 _newTradeBytes
    ) internal virtual returns (bool) {
        return _insertAfter(_toUint(_existingTradeBytes), _toUint(_newTradeBytes));
    }

    /// @notice Inserts a new trade before an existing trade.
    /// @param _existingTrade The existing trade to insert before.
    /// @param _newTrade The new trade to insert.
    /// @return True if insertion succeeded.
    function _insertBefore(
        uint256 _existingTrade,
        uint256 _newTrade
    ) internal virtual returns (bool) {
        return _insert(_existingTrade, _newTrade, PREV);
    }

    /// @notice Inserts a new bytes16 trade before an existing bytes16 trade.
    /// @param _existingTradeBytes The existing trade to insert before.
    /// @param _newTradeBytes The new trade to insert.
    /// @return True if insertion succeeded.
    function _insertBeforeBytes(
        bytes16 _existingTradeBytes,
        bytes16 _newTradeBytes
    ) internal virtual returns (bool) {
        return _insertBefore(_toUint(_existingTradeBytes), _toUint(_newTradeBytes));
    }

    /// @notice Inserts a new trade in the list
    /// @param _existingTrade The existing trade to insert relative to
    /// @param _newTrade The new trade to insert
    /// @param _direction Direction to insert trade (PREV or NEXT)
    /// @return True if insertion succeeded
    function _insert(
        uint256 _existingTrade,
        uint256 _newTrade,
        bool _direction
    ) internal returns (bool) {
        if (tradeExists(_existingTrade) && !tradeExists(_newTrade)) {
            uint256 temp = trades[_existingTrade][_direction];
            _linkTrades(_existingTrade, _newTrade, _direction);
            _linkTrades(_newTrade, temp, _direction);

            size++;
            return true;
        }
        return false;
    }

    // ========================
    // 🟦 Push Helpers
    // ========================

    /// @notice Pushes a new trade to the head of the list.
    /// @param _newTrade The new trade to push.
    /// @return True if push succeeded.
    function _pushHead(uint256 _newTrade) internal virtual returns (bool) {
        return _insert(HEAD, _newTrade, NEXT);
    }

    /// @notice Pushes a new bytes16 trade to the head of the list.
    /// @param _newTradeBytes The new trade to push.
    /// @return True if push succeeded.
    function _pushHeadBytes(bytes16 _newTradeBytes) internal virtual returns (bool) {
        return _pushHead(_toUint(_newTradeBytes));
    }

    /// @notice Pushes a new trade to the tail of the list.
    /// @param _newTrade The new trade to push.
    /// @return True if push succeeded.
    function _pushTail(uint256 _newTrade) internal virtual returns (bool) {
        return _insert(HEAD, _newTrade, PREV);
    }

    /// @notice Pushes a new bytes16 trade to the tail of the list.
    /// @param _newTradeBytes The new trade to push.
    /// @return True if push succeeded.
    function _pushTailBytes(bytes16 _newTradeBytes) internal virtual returns (bool) {
        return _pushTail(_toUint(_newTradeBytes));
    }

    // ========================
    // 🟦 Removal Helpers
    // ========================

    /// @notice Pops the first trade from the head.
    /// @return The removed trade ID, or 0 if empty.
    function _popHead() internal virtual returns (uint256) {
        (, uint256 adj) = getAdjacent(HEAD, NEXT);
        return _remove(adj);
    }

    /// @notice Pops the first bytes16 trade from the head.
    /// @return The removed trade ID, or empty bytes16 if empty.
    function _popHeadBytes() internal virtual returns (bytes16) {
        uint256 tradeUint = _popHead();
        return _toBytes(tradeUint);
    }

    /// @notice Pops the first trade from the tail.
    /// @return The removed trade ID, or 0 if empty.
    function _popTail() internal virtual returns (uint256) {
        (, uint256 adj) = getAdjacent(HEAD, PREV);
        return _remove(adj);
    }

    /// @notice Pops the first bytes16 trade from the tail.
    /// @return The removed trade ID, or empty bytes16 if empty.
    function _popTailBytes() internal virtual returns (bytes16) {
        uint256 tradeUint = _popTail();
        return _toBytes(tradeUint);
    }

    /// @notice Removes a specific trade from the list.
    /// @param _trade The trade ID to remove.
    /// @return The removed trade ID, or 0 if not found.
    function _remove(uint256 _trade) internal returns (uint256) {
        if (_trade == NULL || !tradeExists(_trade)) {
            return 0;
        }
        _linkTrades(trades[_trade][PREV], trades[_trade][NEXT], NEXT);
        delete trades[_trade][PREV];
        delete trades[_trade][NEXT];

        size--;
        return _trade;
    }

    /// @notice Removes a specific bytes16 trade from the list.
    /// @param _tradeBytes The trade ID to remove.
    /// @return The removed trade ID, or empty bytes16 if not found.
    function _removeBytes(bytes16 _tradeBytes) internal virtual returns (bytes16) {
        uint256 tradeUint = _remove(_toUint(_tradeBytes));
        return _toBytes(tradeUint);
    }

    // ========================
    // 🟦 Move Helpers
    // ========================

    /// @notice Move an trade to a new position in the list.
    /// @param _trade The trade to move.
    /// @param _target The reference trade for insertion.
    /// @param _direction The direction relative to the target (PREV = before, NEXT = after).
    /// @return True if the move succeeded.
    function _move(
        uint256 _trade,
        uint256 _target,
        bool _direction
    ) internal virtual returns (bool) {
        if (
            _trade == NULL ||
            _trade == _target ||
            !tradeExists(_trade) ||
            (_target != HEAD && !tradeExists(_target))
        ) {
            return false;
        }

        _remove(_trade);

        if (_direction == PREV) {
            _insertBefore(_target, _trade);
        } else {
            _insertAfter(_target, _trade);
        }

        return true;
    }

    /// @notice Move a bytes16 trade to a new position in the list.
    /// @param _tradeBytes The trade to move.
    /// @param _targetBytes The reference trade for insertion.
    /// @param _direction The direction relative to the target (PREV = before, NEXT = after).
    /// @return True if the move succeeded.
    function _moveBytes(
        bytes16 _tradeBytes,
        bytes16 _targetBytes,
        bool _direction
    ) internal virtual returns (bool) {
        return _move(_toUint(_tradeBytes), _toUint(_targetBytes), _direction);
    }

    // ========================
    // 🟦 Linking Helpers
    // ========================

    /// @notice Links two trades together in the list
    /// @param _existingTrade The existing trade
    /// @param _adjacentTrade The adjacent trade to link
    /// @param _direction The direction to link (PREV or NEXT)
    function _linkTrades(
        uint256 _existingTrade,
        uint256 _adjacentTrade,
        bool _direction
    ) internal {
        trades[_adjacentTrade][!_direction] = _existingTrade;
        trades[_existingTrade][_direction] = _adjacentTrade;
    }

    // ========================
    // 🟦 Getters
    // ========================

    /// @notice Returns the previous and next trades of a given trade.
    /// @param _trade The trade ID to query.
    /// @return exists True if the trade exists.
    /// @return prev The previous trade ID.
    /// @return next The next trade ID.
    function getTrade(uint256 _trade) public view returns (bool, uint256, uint256) {
        if (!tradeExists(_trade)) {
            return (false, 0, 0);
        }
        return (true, trades[_trade][PREV], trades[_trade][NEXT]);
    }

    /// @notice Returns the previous and next bytes16 trades of a given bytes16 trade.
    /// @param _tradeBytes The trade ID to query.
    /// @return exists True if the trade exists.
    /// @return prev The previous trade ID.
    /// @return next The next trade ID.
    function getTradeBytes(
        bytes16 _tradeBytes
    ) public view returns (bool, bytes16, bytes16) {
        uint256 tradeUint = _toUint(_tradeBytes);
        (bool exists, uint256 prevUint, uint256 nextUint) = getTrade(tradeUint);
        return (exists, _toBytes(prevUint), _toBytes(nextUint));
    }

    /// @notice Returns the adjacent trade in a given direction.
    /// @param _trade The trade ID to query.
    /// @param _direction NEXT for next, PREV for previous.
    /// @return exists True if the trade exists.
    /// @return adjacent The adjacent trade ID.
    function getAdjacent(
        uint256 _trade,
        bool _direction
    ) public view returns (bool, uint256) {
        if (!tradeExists(_trade)) {
            return (false, 0);
        }
        return (true, trades[_trade][_direction]);
    }

    /// @notice Returns the adjacent bytes16 trade in a given direction.
    /// @param _tradeBytes The trade ID to query.
    /// @param _direction NEXT for next, PREV for previous.
    /// @return exists True if the trade exists.
    /// @return adjacent The adjacent trade ID.
    function getAdjacentBytes(
        bytes16 _tradeBytes,
        bool _direction
    ) public view returns (bool, bytes16) {
        uint256 tradeUint = _toUint(_tradeBytes);
        (bool exists, uint256 adjacentUint) = getAdjacent(tradeUint, _direction);
        return (exists, _toBytes(adjacentUint));
    }

    /// @notice Returns the next trade.
    /// @param _trade The trade ID to query.
    /// @return exists True if the trade exists.
    /// @return next The next trade ID.
    function getNext(uint256 _trade) public view returns (bool, uint256) {
        return getAdjacent(_trade, NEXT);
    }

    /// @notice Returns the next bytes16 trade.
    /// @param _tradeBytes The bytes16 trade ID to query.
    /// @return exists True if the trade exists.
    /// @return next The next trade ID.
    function getNextBytes(bytes16 _tradeBytes) public view returns (bool, bytes16) {
        return getAdjacentBytes(_tradeBytes, NEXT);
    }

    /// @notice Returns the previous trade.
    /// @param _trade The trade ID to query.
    /// @return exists True if the trade exists.
    /// @return prev The previous trade ID.
    function getPrev(uint256 _trade) public view returns (bool, uint256) {
        return getAdjacent(_trade, PREV);
    }

    /// @notice Returns the previous bytes16 trade.
    /// @param _tradeBytes The bytes16 trade ID to query.
    /// @return exists True if the trade exists.
    /// @return prev The previous trade ID.
    function getPrevBytes(bytes16 _tradeBytes) public view returns (bool, bytes16) {
        return getAdjacentBytes(_tradeBytes, PREV);
    }

    /// @notice Returns the total number of trades in the list.
    /// @return The size of the list.
    function getTradeBookSize() public view returns (uint256) {
        return size;
    }

    // ========================
    // 🟦 Conversion Getters
    // ========================

    /// @notice Converts bytes16 trade ID to uint256
    /// @param _tradeBytes The bytes16 trade ID
    /// @return The uint256 representation, or 0 if not found
    function getTradeUintFromBytes(
        bytes16 _tradeBytes
    ) public view returns (uint256) {
        return _tradesBytesToUint[_tradeBytes];
    }

    /// @notice Converts uint256 trade ID to bytes16
    /// @param _tradeUint The uint256 trade ID
    /// @return The bytes16 representation, or 0 if not found
    function getTradeBytesFromUint(
        uint256 _tradeUint
    ) public view returns (bytes16) {
        return _tradesUintToBytes[_tradeUint];
    }

    /// @notice Checks if a bytes16 trade ID exists in the mapping
    /// @param _tradeBytes The bytes16 trade ID to check
    /// @return True if the mapping exists
    function tradeBytesMappingExists(
        bytes16 _tradeBytes
    ) public view returns (bool) {
        return _tradesBytesToUint[_tradeBytes] != 0;
    }

    /// @notice Checks if a uint256 trade ID has a bytes16 mapping
    /// @param _tradeUint The uint256 trade ID to check
    /// @return True if the mapping exists
    function tradeUintMappingExists(uint256 _tradeUint) public view returns (bool) {
        return _tradesUintToBytes[_tradeUint] != bytes16(0);
    }
}
