import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase/supabase_providers.dart';
import '../products/product_catalog_provider.dart';
import '../products/product_repository.dart';
import '../products/widgets/catalog_state_notice.dart';

class AdminCategoriesScreen extends ConsumerWidget {
  const AdminCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(productCategoriesProvider);
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: CatalogStateNotice()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Categories',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  FilledButton.icon(
                    key: const ValueKey('admin-add-category'),
                    onPressed: () => _editCategory(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Add category'),
                  ),
                ],
              ),
            ),
          ),
          ...state.when(
            loading: () => [
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (error, stack) => [
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    'Categories could not be loaded. ${error.toString()}',
                  ),
                ),
              ),
            ],
            data: (categories) => categories.isEmpty
                ? [
                    const SliverFillRemaining(
                      child: Center(child: Text('No categories yet.')),
                    ),
                  ]
                : [
                    SliverList.separated(
                      itemCount: categories.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        return ListTile(
                          title: Text(category.name),
                          subtitle: Text(
                            '${category.productCount} products${category.description.isEmpty ? '' : ' · ${category.description}'}',
                          ),
                          trailing: Wrap(
                            children: [
                              IconButton(
                                tooltip: 'Edit ${category.name}',
                                onPressed: () =>
                                    _editCategory(context, ref, category),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: 'Delete ${category.name}',
                                onPressed: category.productCount == 0
                                    ? () => _deleteCategory(
                                        context,
                                        ref,
                                        category,
                                      )
                                    : () => _showCannotDelete(
                                        context,
                                        category.productCount,
                                      ),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
          ),
        ],
      ),
    );
  }

  Future<void> _editCategory(
    BuildContext context,
    WidgetRef ref, [
    ProductCategory? category,
  ]) async {
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController(text: category?.name ?? '');
    final description = TextEditingController(
      text: category?.description ?? '',
    );
    final imageUrl = TextEditingController(text: category?.imageUrl ?? '');
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(category == null ? 'Add category' : 'Edit category'),
        content: SizedBox(
          width: 440,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Category name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a category name.'
                      : null,
                ),
                TextFormField(
                  controller: description,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                TextFormField(
                  controller: imageUrl,
                  decoration: const InputDecoration(
                    labelText: 'Image URL (optional)',
                  ),
                  keyboardType: TextInputType.url,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    final uri = Uri.tryParse(value.trim());
                    return uri != null &&
                            {'http', 'https'}.contains(uri.scheme) &&
                            uri.host.isNotEmpty
                        ? null
                        : 'Enter a valid image URL.';
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Save category'),
          ),
        ],
      ),
    );
    if (result != true || !context.mounted) {
      name.dispose();
      description.dispose();
      imageUrl.dispose();
      return;
    }
    try {
      await ref
          .read(productRepositoryProvider)
          .saveCategory(
            ProductCategory(
              id: category?.id ?? '',
              name: name.text,
              slug: '',
              description: description.text,
              imageUrl: imageUrl.text,
            ),
            create: category == null,
          );
      ref.invalidate(productCategoriesProvider);
      ref.invalidate(productCatalogProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Category saved.')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Category could not be saved: $error')),
        );
      }
    } finally {
      name.dispose();
      description.dispose();
      imageUrl.dispose();
    }
  }

  Future<void> _deleteCategory(
    BuildContext context,
    WidgetRef ref,
    ProductCategory category,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete category?'),
        content: const Text(
          'The category will be removed. Categories with products cannot be deleted; reassign those products first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete category'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(productRepositoryProvider).deleteCategory(category.id);
      ref.invalidate(productCategoriesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Category deleted.')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Category could not be deleted: $error')),
        );
      }
    }
  }

  void _showCannotDelete(BuildContext context, int count) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Category contains products'),
        content: Text(
          'Reassign or delete the $count products in this category before deleting it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
