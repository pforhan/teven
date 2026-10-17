import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_exception.dart';
import '../core/services/list_query.dart';
import '../models/event.dart';
import '../models/inventory.dart';
import '../providers/service_providers.dart';
import 'picker_fields.dart';

class InventoryAssociationEditor extends ConsumerStatefulWidget {
  const InventoryAssociationEditor({
    super.key,
    required this.initialInventoryItems,
    required this.onInventoryItemsChange,
    required this.organizationId,
  });

  final List<EventInventoryItem> initialInventoryItems;
  final ValueChanged<List<EventInventoryItem>> onInventoryItemsChange;
  final String? organizationId;

  @override
  ConsumerState<InventoryAssociationEditor> createState() =>
      _InventoryAssociationEditorState();
}

class _InventoryAssociationEditorState
    extends ConsumerState<InventoryAssociationEditor> {
  List<InventoryItemResponse> _available = [];
  int? _selectedId;
  int _quantity = 1;
  final _quantityController = TextEditingController(text: '1');
  List<EventInventoryItem> _associated = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _associated = List.of(widget.initialInventoryItems);
    _refresh();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant InventoryAssociationEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.organizationId != widget.organizationId) {
      _associated = [];
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final orgStr = widget.organizationId;
    if (orgStr == null || orgStr.isEmpty) {
      setState(() {
        _available = [];
        _selectedId = null;
      });
      widget.onInventoryItemsChange(_associated);
      return;
    }
    final orgId = int.tryParse(orgStr);
    if (orgId == null) return;
    try {
      final page = await ref
          .read(inventoryServiceProvider)
          .getAllInventoryItems(
            ListQuery(
              limit: 1000,
              organizationId: orgId,
              sortBy: 'name',
              sortOrder: SortOrder.asc,
            ),
          );
      if (!mounted) return;
      setState(() {
        _available = page.items;
        if (page.items.isNotEmpty && _selectedId == null) {
          _selectedId = page.items.first.inventoryId;
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  void _addItem() {
    final id = _selectedId;
    if (id == null || _quantity <= 0) {
      setState(
        () => _error = 'Please select a valid inventory item and quantity.',
      );
      return;
    }
    final existingIndex = _associated.indexWhere((i) => i.inventoryId == id);
    if (existingIndex > -1) {
      final updated = List<EventInventoryItem>.of(_associated);
      final current = updated[existingIndex];
      updated[existingIndex] = EventInventoryItem(
        inventoryId: current.inventoryId,
        itemName: current.itemName,
        quantity: current.quantity + _quantity,
      );
      setState(() {
        _associated = updated;
        _error = null;
      });
    } else {
      final selected = _available.where((i) => i.inventoryId == id).firstOrNull;
      if (selected == null) return;
      setState(() {
        _associated = [
          ..._associated,
          EventInventoryItem(
            inventoryId: selected.inventoryId,
            itemName: selected.name,
            quantity: _quantity,
          ),
        ];
        _error = null;
      });
    }
    widget.onInventoryItemsChange(_associated);
  }

  void _remove(int id) {
    setState(() {
      _associated = _associated.where((i) => i.inventoryId != id).toList();
    });
    widget.onInventoryItemsChange(_associated);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_error != null) ...[
          Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 8),
        ],
        if (_available.isEmpty)
          const Text('No inventory items available for this organization.')
        else ...[
          Row(
            children: [
              Expanded(
                child: DropdownButton<int>(
                  value: _selectedId,
                  isExpanded: true,
                  items: [
                    for (final item in _available)
                      DropdownMenuItem<int>(
                        value: item.inventoryId,
                        child: Text(
                          '${item.name} (Current Qty: ${item.quantity})',
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _selectedId = v),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: NumberField(
                  controller: _quantityController,
                  label: 'Qty',
                  onChanged: (v) => _quantity = int.tryParse(v) ?? 1,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _addItem,
                child: const Text('Add Item'),
              ),
            ],
          ),
        ],
        if (_associated.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final item in _associated)
            ListTile(
              title: Text(
                '${_available.where((i) => i.inventoryId == item.inventoryId).firstOrNull?.name ?? 'ID: ${item.inventoryId}'} - Quantity: ${item.quantity}',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _remove(item.inventoryId),
              ),
            ),
        ],
      ],
    );
  }
}
