import 'package:flutter/material.dart';

import '../../../core/services/tip_store.dart';
import '../../theme/tokens.dart';
import '../../widgets/motion.dart';

/// "開発者を応援する": three tips through In-App Purchase. Nothing is unlocked;
/// the screen says so before anyone pays.
class TipScreen extends StatefulWidget {
  const TipScreen({super.key});

  @override
  State<TipScreen> createState() => _TipScreenState();
}

class _TipScreenState extends State<TipScreen> {
  final store = TipStore.instance;

  @override
  void initState() {
    super.initState();
    store.reset();
    store.load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('開発者を応援する')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          if (store.status == TipStatus.thanks) return _thanks(context);
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
            children: [
              const Text('SUPPORT',
                  style: TextStyle(fontFamily: 'Helvetica', color: Palette.gold, fontSize: 11, letterSpacing: 2.4)),
              const SizedBox(height: 8),
              const Text('EnCura を応援する',
                  style: TextStyle(color: Palette.text, fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              const Text(
                'EnCura は学生が個人で開発しています。いただいた応援は、実際に美術館や展覧会へ足を運んで確かめることや、解説と作品情報の質を上げることに使います。',
                style: TextStyle(color: Palette.textSub, fontSize: 13, height: 1.9),
              ),
              const SizedBox(height: 8),
              const Text(
                '応援しても、使える機能や内容は変わりません（お礼のメッセージが表示されるだけです）。',
                style: TextStyle(color: Palette.textSub, fontSize: 12, height: 1.8),
              ),
              const SizedBox(height: 24),
              for (final option in tipOptions) _OptionTile(option: option, store: store),
              if (store.message != null) ...[
                const SizedBox(height: 8),
                Text(store.message!, style: const TextStyle(color: Palette.textSub, fontSize: 12)),
              ],
              if (store.loaded && !store.available) ...[
                const SizedBox(height: 8),
                const Text('いまは App Store に接続できないため、応援できません。時間をおいてお試しください。',
                    style: TextStyle(color: Palette.textSub, fontSize: 12, height: 1.8)),
              ],
              const SizedBox(height: 24),
              const Text(
                'お支払いは Apple ID に請求されます。購入の確認は App Store の画面で行われ、EnCura がお支払い情報を受け取ることはありません。',
                style: TextStyle(color: Palette.textSub, fontSize: 11, height: 1.8),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _thanks(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.volunteer_activism, color: Palette.gold, size: 40),
            const SizedBox(height: 20),
            const Text('ありがとうございます！',
                style: TextStyle(color: Palette.text, fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            const Text('いただいた応援は、美術館や展覧会に足を運ぶことと、EnCura の質を上げることに使います。',
                textAlign: TextAlign.center, style: TextStyle(color: Palette.textSub, fontSize: 13, height: 1.8)),
            const SizedBox(height: 28),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: Palette.gold,
                side: const BorderSide(color: Palette.gold),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              child: const Text('閉じる'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.option, required this.store});

  final TipOption option;
  final TipStore store;

  @override
  Widget build(BuildContext context) {
    final busy = store.pendingProduct == option.productId;
    final enabled = store.canBuy(option);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Pressable(
        onTap: enabled ? () => store.buy(option) : () {},
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: Palette.frame,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Palette.line),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(option.title,
                    style: const TextStyle(color: Palette.text, fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              if (busy)
                const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Palette.gold))
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: enabled ? Palette.gold : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: enabled ? Palette.gold : Palette.line),
                  ),
                  child: Text(store.priceOf(option),
                      style: TextStyle(
                          color: enabled ? Palette.room : Palette.textSub, fontSize: 13, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
