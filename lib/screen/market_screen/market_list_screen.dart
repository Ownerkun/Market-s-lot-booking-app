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
              return name.contains(query);
            })
            .toList()
            .cast<Map<String, dynamic>>();
      } else {
        _filteredMarkets = []; // Clear filtered results when search is empty
      }
    });
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _isSearching = false;
      _filteredMarkets = []; // Clear filtered results
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
        title: _isSearching
            ? TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search markets...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white70),
                  contentPadding: EdgeInsets.zero, // Better alignment
                ),
                style: TextStyle(color: Colors.white),
                onChanged: (value) {
                  if (value.isEmpty) {
                    _clearSearch(); // Clear search when field is emptied
                  }
                },
              )
            : Text(
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
          AnimatedSwitcher(
            duration: Duration(milliseconds: 300),
            child: _isSearching
                ? IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
                    onPressed: _clearSearch,
                  )
                : IconButton(
                    icon: Icon(Icons.search, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        _isSearching = true;
                      });
                    },
                  ),
          ),
          IconButton(
            icon: Icon(Icons.place, color: Colors.white),
            onPressed: () {
              // Handle location icon press
            },
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: Duration(milliseconds: 300),
        child: authProvider.isLoading
            ? Center(
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
              )
            : marketsToDisplay.isEmpty
                ? Center(
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
                  )
                : RefreshIndicator(
                    onRefresh: () async {
                      await authProvider.fetchMarkets();
                    },
                    color: theme.primaryColor,
                    child: CustomScrollView(
                      controller: _scrollController,
                      physics: AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
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
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final market = marketsToDisplay[index]
                                  as Map<String, dynamic>;
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
              heroTag: 'addMarketButton', // Add this unique hero tag
            )
          : null,
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
                  Image.network(
                    widget.market['imageUrl'] ??
                        'https://picsum.photos/400/200',
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
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
                        Row(
                          children: [
                            Icon(
                              Icons.category,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            SizedBox(width: 4),
                            Text(
                              widget.market['type'] ?? 'Market Type',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
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
