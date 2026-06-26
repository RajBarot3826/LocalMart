import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../theme/app_theme.dart';
import '../utils/cart_manager.dart';

class ProductQuantitySelector extends StatefulWidget {
  final Product product;

  const ProductQuantitySelector({super.key, required this.product});

  @override
  State<ProductQuantitySelector> createState() => _ProductQuantitySelectorState();
}

class _ProductQuantitySelectorState extends State<ProductQuantitySelector> {
  void _showClearCartDialog(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Replace cart item?'),
        content: const Text('Your cart contains items from another store. Do you want to discard the selection and add items from this store?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('NO', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              CartManager().clearCart();
              CartManager().addProduct(product);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text('REPLACE', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: CartManager(),
      builder: (context, child) {
        final qty = CartManager().getQuantity(widget.product);
        
        if (qty == 0) {
          return SizedBox(
            height: 32,
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                try {
                  CartManager().addProduct(widget.product);
                } catch (e) {
                  if (e.toString().contains("DifferentStore")) {
                    _showClearCartDialog(context, widget.product);
                  }
                }
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.primary),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text(
                'ADD',
                style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          );
        }

        return Container(
          height: 32,
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () => CartManager().updateQuantity(widget.product, qty - 1),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(Icons.remove, color: Colors.white, size: 16),
                ),
              ),
              Text(
                qty.toString(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              InkWell(
                onTap: () {
                  try {
                    CartManager().updateQuantity(widget.product, qty + 1);
                  } catch (e) {
                     if (e.toString().contains("DifferentStore")) {
                       _showClearCartDialog(context, widget.product);
                     }
                  }
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(Icons.add, color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
