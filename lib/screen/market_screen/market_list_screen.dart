import 'package:flutter/material.dart';
import 'package:market_lot_app/provider/market_provider.dart';
import 'package:market_lot_app/screen/market_screen/market_create_screen.dart';
import 'package:provider/provider.dart';
import 'package:market_lot_app/provider/auth_provider.dart';
import 'package:market_lot_app/screen/market_screen/market_lot_screen.dart';

class MarketListScreen extends StatefulWidget {
  @override
  _MarketListScreenState createState() => _MarketListScreenState();
}

class _MarketListScreenState extends State<MarketListScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredMarkets = [];
  bool _isSearching = false;
  final FocusNode _searchFocusNode = FocusNode();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      authProvider.fetchMarkets();
    });
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final query = _searchController.text.toLowerCase();

    setState(() {
      _isSearching = query.isNotEmpty;
      if (_isSearching) {
        _filteredMarkets = (authProvider.markets as List<dynamic>)
            .where((market) {
              final marketMap = market as Map<String, dynamic>;
              final name = marketMap['name']?.toString().toLowerCase() ?? '';
              final location =
                  marketMap['location']?.toString().toLowerCase() ?? '';
              final tags = marketMap['tags'] != null
                  ? (marketMap['tags'] as List)
                      .map((t) => t['name'] as String)
                      .join(' ')
                      .toLowerCase()
                  : '';

              // Improved search to include location and tags
              return name.contains(query) ||
                  location.contains(query) ||
                  tags.contains(query);
            })
            .toList()
            .cast<Map<String, dynamic>>();
      } else {
        _filteredMarkets = [];
      }
    });
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _isSearching = false;
      _filteredMarkets = [];
      _searchFocusNode.unfocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final marketsToDisplay =
        _isSearching ? _filteredMarkets : authProvider.markets;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Market Places',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: theme.primaryColor,
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.place, color: Colors.white),
            onPressed: () {
              // Handle location icon press
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await authProvider.fetchMarkets();
        },
        color: theme.primaryColor,
        child: CustomScrollView(
          controller: _scrollController,
          physics: AlwaysScrollableScrollPhysics(),
          slivers: [
            // Search Bar Section
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: SearchBar(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onClearSearch: _clearSearch,
                  isSearching: _isSearching,
                ),
              ),
            ),

            // Title Section
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Available Market Spaces',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            // Loading Indicator
            if (authProvider.isLoading)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.primaryColor,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Loading Markets...',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              )

            // Empty State
            else if (marketsToDisplay.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.store_mall_directory_outlined,
                        size: 80,
                        color: Colors.grey[300],
                      ),
                      SizedBox(height: 16),
                      Text(
                        _isSearching
                            ? 'No markets found for "${_searchController.text}"'
                            : 'No markets available',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              )

            // Market List
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final market = marketsToDisplay[index];
                    return AnimatedMarketCard(
                      market: market,
                      index: index,
                    );
                  },
                  childCount: marketsToDisplay.length,
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: authProvider.userRole == 'LANDLORD'
          ? FloatingActionButton(
              onPressed: () {
                Navigator.of(context).push(
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        MarketCreationWizard(),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                      return FadeTransition(
                        opacity: animation,
                        child: child,
                      );
                    },
                  ),
                );
              },
              child: Icon(Icons.add, color: Colors.white),
              backgroundColor: theme.primaryColor,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              heroTag: 'addMarketButton',
            )
          : null,
    );
  }
}

// New dedicated SearchBar widget
class SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Function onClearSearch;
  final bool isSearching;

  const SearchBar({
    Key? key,
    required this.controller,
    required this.focusNode,
    required this.onClearSearch,
    required this.isSearching,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        decoration: InputDecoration(
          hintText: 'Search markets by name, location or tags...',
          prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
          suffixIcon: isSearching
              ? IconButton(
                  icon: Icon(Icons.close, color: Colors.grey[600]),
                  onPressed: () => onClearSearch(),
                )
              : null,
          border: InputBorder.none,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[200]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Theme.of(context).primaryColor),
          ),
          contentPadding: EdgeInsets.symmetric(vertical: 16),
          fillColor: Colors.white,
          filled: true,
        ),
        style: TextStyle(
          fontSize: 16,
          color: Colors.grey[800],
        ),
      ),
    );
  }
}

class AnimatedMarketCard extends StatefulWidget {
  final Map<String, dynamic> market;
  final int index;

  const AnimatedMarketCard({
    Key? key,
    required this.market,
    required this.index,
  }) : super(key: key);

  @override
  _AnimatedMarketCardState createState() => _AnimatedMarketCardState();
}

class _AnimatedMarketCardState extends State<AnimatedMarketCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );

    Future.delayed(Duration(milliseconds: 100 * widget.index), () {
      if (mounted) {
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Extract and process tags using the improved TagHelper
    final tags = TagHelper.extractTags(widget.market);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: child,
          ),
        );
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    ChangeNotifierProvider(
                  create: (_) => MarketProvider(
                    widget.market['id'],
                    Provider.of<AuthProvider>(context, listen: false),
                  ),
                  child: MarketLayoutScreen(marketId: widget.market['id']),
                ),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                  final fadeAnimation = animation.drive(
                    CurveTween(curve: Curves.easeOut),
                  );

                  return FadeTransition(
                    opacity: fadeAnimation,
                    child: child,
                  );
                },
                transitionDuration: Duration(milliseconds: 300),
              ),
            );
          },
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            shadowColor: Colors.black.withOpacity(0.2),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      Image.network(
                        widget.market['imageUrl'] ??
                            'https://picsum.photos/400/200',
                        width: double.infinity,
                        height: 180,
                        fit: BoxFit.cover,
                      ),
                      // Gradient overlay for better text visibility if needed
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 60,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.3),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.market['name'] ?? 'Market Name',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        // Use the MarketTagList widget for tags display
                        if (tags.isNotEmpty) MarketTagList(tags: tags),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                widget.market['location'] ?? 'Location',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Dedicated widget for market tags
class MarketTagList extends StatelessWidget {
  final List<MarketTag> tags;

  const MarketTagList({
    Key? key,
    required this.tags,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: tags.map((tag) => MarketTagChip(tag: tag)).toList(),
    );
  }
}

// Tag chip widget
class MarketTagChip extends StatelessWidget {
  final MarketTag tag;

  const MarketTagChip({
    Key? key,
    required this.tag,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tag.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tag.borderColor),
      ),
      child: Text(
        tag.name,
        style: TextStyle(
          fontSize: 12,
          color: tag.textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// Tag model class
class MarketTag {
  final String name;
  final Color backgroundColor;
  final Color textColor;
  final Color borderColor;

  MarketTag({
    required this.name,
    required this.backgroundColor,
    required this.textColor,
    required this.borderColor,
  });
}

// Helper class for tag-related functionality
class TagHelper {
  // Extract tags from market data
  static List<MarketTag> extractTags(Map<String, dynamic> market) {
    if (market['tags'] == null) return [];

    final rawTags = market['tags'] as List;
    return rawTags.map((tag) {
      final name = tag['name'] as String;

      // You can customize tag colors based on category or other properties
      final tagCategory = tag['category'] as String? ?? 'default';

      return _getTagWithStyle(name, tagCategory);
    }).toList();
  }

  // Get styled tag based on category
  static MarketTag _getTagWithStyle(String name, String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return MarketTag(
          name: name,
          backgroundColor: Colors.orange[50]!,
          textColor: Colors.orange[800]!,
          borderColor: Colors.orange[100]!,
        );
      case 'organic':
        return MarketTag(
          name: name,
          backgroundColor: Colors.green[50]!,
          textColor: Colors.green[800]!,
          borderColor: Colors.green[100]!,
        );
      case 'craft':
        return MarketTag(
          name: name,
          backgroundColor: Colors.purple[50]!,
          textColor: Colors.purple[800]!,
          borderColor: Colors.purple[100]!,
        );
      case 'specialty':
        return MarketTag(
          name: name,
          backgroundColor: Colors.blue[50]!,
          textColor: Colors.blue[800]!,
          borderColor: Colors.blue[100]!,
        );
      default:
        return MarketTag(
          name: name,
          backgroundColor: Colors.grey[50]!,
          textColor: Colors.grey[800]!,
          borderColor: Colors.grey[200]!,
        );
    }
  }
}
