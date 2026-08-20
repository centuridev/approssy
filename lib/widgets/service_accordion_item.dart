import 'package:flutter/material.dart';

import '../models/service.dart';
import '../pages/booking_page.dart';

class ServiceAccordionItemWrapper extends StatefulWidget {
  final Service service;
  final int index;

  // Nuevos parámetros para reserva múltiple.
  final bool isSelected;
  final List<ServiceExtra> selectedExtras;
  final ValueChanged<Service>? onToggleService;
  final void Function(Service, ServiceExtra)? onToggleExtra;

  const ServiceAccordionItemWrapper({
    super.key,
    required this.service,
    required this.index,
    this.isSelected = false,
    this.selectedExtras = const [],
    this.onToggleService,
    this.onToggleExtra,
  });

  @override
  State<ServiceAccordionItemWrapper> createState() =>
      _ServiceAccordionItemWrapperState();
}

class _ServiceAccordionItemWrapperState
    extends State<ServiceAccordionItemWrapper> {
  static String? expandedServiceId;

  @override
  Widget build(BuildContext context) {
    final serviceKey = widget.service.id.isNotEmpty
        ? widget.service.id
        : '${widget.service.category}_${widget.index}';

    final isExpanded = expandedServiceId == serviceKey;

    return ServiceAccordionItem(
      service: widget.service,
      isExpanded: isExpanded,
      isSelected: widget.isSelected,
      selectedExtras: widget.selectedExtras,
      onTap: () {
        setState(() {
          expandedServiceId = isExpanded ? null : serviceKey;
        });
      },
      onToggleService: widget.onToggleService,
      onToggleExtra: widget.onToggleExtra,
    );
  }
}

class ServiceAccordionItem extends StatelessWidget {
  final Service service;
  final bool isExpanded;
  final bool isSelected;

  final List<ServiceExtra> selectedExtras;

  final VoidCallback onTap;
  final ValueChanged<Service>? onToggleService;
  final void Function(Service, ServiceExtra)? onToggleExtra;

  const ServiceAccordionItem({
    super.key,
    required this.service,
    required this.isExpanded,
    required this.isSelected,
    required this.selectedExtras,
    required this.onTap,
    this.onToggleService,
    this.onToggleExtra,
  });

  static const Color gold = Color(0xFFDDA33B);
  static const Color dark = Color(0xFF111111);

  bool get multiSelectionEnabled => onToggleService != null;

  bool _isExtraSelected(ServiceExtra extra) {
    return selectedExtras.any((selectedExtra) => selectedExtra.id == extra.id);
  }

  void showServiceImage(BuildContext context, String image) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(10),
          child: Stack(
            children: [
              InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: image.startsWith('http')
                      ? Image.network(
                          image,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return _largeImagePlaceholder();
                          },
                        )
                      : Image.asset(
                          image,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return _largeImagePlaceholder();
                          },
                        ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> showServiceDetails(BuildContext context) async {
    final details = service.details.trim();

    if (details.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nessun dettaglio disponibile per questo servizio.'),
        ),
      );

      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 18, 10, 8),
          contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
          title: Row(
            children: [
              const Icon(Icons.info_outline, color: gold),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  service.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Chiudi',
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(
              details,
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text(
                'CHIUDI',
                style: TextStyle(color: gold, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      width: 85,
      height: 85,
      color: Colors.grey.shade200,
      alignment: Alignment.center,
      child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey),
    );
  }

  Widget _largeImagePlaceholder() {
    return Container(
      width: 300,
      height: 300,
      color: Colors.white,
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_not_supported_outlined,
        size: 60,
        color: Colors.grey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: isSelected ? dark : gold,
          width: isSelected ? 2 : 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onTap,
            child: SizedBox(
              height: 48,
              child: Row(
                children: [
                  const SizedBox(width: 8),

                  SizedBox(
                    width: 35,
                    child: Center(
                      child: Icon(
                        isExpanded ? Icons.remove : Icons.add,
                        color: dark,
                        size: 22,
                      ),
                    ),
                  ),

                  Expanded(
                    child: Text(
                      service.name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: dark,
                      ),
                    ),
                  ),

                  if (multiSelectionEnabled)
                    SizedBox(
                      width: 40,
                      child: Icon(
                        isSelected
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: isSelected ? gold : Colors.grey,
                        size: 22,
                      ),
                    )
                  else
                    const SizedBox(width: 35),
                ],
              ),
            ),
          ),

          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _expandedContent(context),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  Widget _expandedContent(BuildContext context) {
    final hasDetails = service.details.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(15, 10, 15, 15),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(9)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  showServiceImage(context, service.image);
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: service.image.startsWith('http')
                      ? Image.network(
                          service.image,
                          width: 85,
                          height: 85,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _imagePlaceholder();
                          },
                        )
                      : Image.asset(
                          service.image,
                          width: 85,
                          height: 85,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _imagePlaceholder();
                          },
                        ),
                ),
              ),

              const SizedBox(width: 18),

              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      service.price,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        color: gold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.schedule,
                          size: 16,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${service.duration} min',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    _buildMainActions(context, hasDetails),
                  ],
                ),
              ),
            ],
          ),

          if (multiSelectionEnabled &&
              isSelected &&
              service.extras.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            _buildExtrasSection(),
          ],
        ],
      ),
    );
  }

  Widget _buildMainActions(BuildContext context, bool hasDetails) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        SizedBox(
          height: 40,
          child: ElevatedButton.icon(
            onPressed: () {
              if (multiSelectionEnabled) {
                onToggleService?.call(service);
                return;
              }

              // Compatibilidad temporal con el sistema anterior.
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) {
                    return BookingPage(service: service);
                  },
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isSelected ? gold : dark,
              foregroundColor: isSelected ? dark : gold,
              elevation: 4,
              padding: const EdgeInsets.symmetric(horizontal: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
            ),
            icon: Icon(isSelected ? Icons.check : Icons.add, size: 18),
            label: Text(
              multiSelectionEnabled
                  ? isSelected
                        ? 'AGGIUNTO'
                        : 'AGGIUNGI'
                  : 'Prenotare',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ),

        if (hasDetails)
          SizedBox(
            height: 40,
            child: OutlinedButton.icon(
              onPressed: () {
                showServiceDetails(context);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: dark,
                side: const BorderSide(color: gold, width: 1.2),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              icon: const Icon(Icons.info_outline, color: gold, size: 18),
              label: const Text(
                'Dettagli',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildExtrasSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.auto_awesome, color: gold, size: 19),
            SizedBox(width: 8),
            Text(
              'Personalizza il servizio',
              style: TextStyle(
                color: dark,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),

        const SizedBox(height: 5),

        Text(
          'Puoi aggiungere uno o più extra.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
        ),

        const SizedBox(height: 10),

        ...service.extras.map((extra) => _buildExtraItem(extra)),
      ],
    );
  }

  Widget _buildExtraItem(ServiceExtra extra) {
    final selected = _isExtraSelected(extra);

    final priceText = extra.price > 0
        ? '+${extra.price.toStringAsFixed(2)} €'
        : 'Incluso';

    final durationText = extra.duration > 0 ? '+${extra.duration} min' : '';

    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: () {
        onToggleExtra?.call(service, extra);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? gold.withValues(alpha: 0.12) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: selected ? gold : Colors.grey.shade300,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_box : Icons.check_box_outline_blank,
              color: selected ? gold : Colors.grey.shade600,
            ),

            const SizedBox(width: 10),

            Expanded(
              child: Text(
                extra.name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: dark,
                ),
              ),
            ),

            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  priceText,
                  style: const TextStyle(
                    color: gold,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),

                if (durationText.isNotEmpty)
                  Text(
                    durationText,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
