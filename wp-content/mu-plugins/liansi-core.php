<?php
/**
 * Plugin Name: Liansi Core
 * Description: 注册联思官网的内容类型（产品、解决方案、客户）与产品分类。设置与线上 CPT UI 配置一一对应。
 * Version:     1.0.0
 * Author:      Liansi
 *
 * 这是 must-use 插件：放在 wp-content/mu-plugins/ 下自动生效，后台无法停用。
 */

defined( 'ABSPATH' ) || exit;

// Priority 20 runs after CPT UI (priority 10). While CPT UI is still active it has
// already registered these types, so we skip them and nothing changes on the site.
// Once CPT UI is deactivated, this file takes over with identical settings.
add_action( 'init', 'liansi_register_content_types', 20 );

/**
 * Build a full set of Chinese labels for a post type.
 *
 * @param string $name  Display name, e.g. 产品.
 * @param array  $extra Labels that differ from the generated defaults.
 * @return array
 */
function liansi_post_type_labels( $name, array $extra = array() ) {
	return array_merge(
		array(
			'name'               => $name,
			'singular_name'      => $name,
			'menu_name'          => $name,
			'name_admin_bar'     => $name,
			'all_items'          => '全部' . $name,
			'add_new'            => '添加' . $name,
			'add_new_item'       => '添加' . $name,
			'edit_item'          => '编辑' . $name,
			'new_item'           => '新' . $name,
			'view_item'          => '查看' . $name,
			'view_items'         => '查看' . $name,
			'search_items'       => '搜索' . $name,
			'not_found'          => '未找到' . $name,
			'not_found_in_trash' => '回收站中未找到' . $name,
		),
		$extra
	);
}

function liansi_register_content_types() {
	$common = array(
		'public'              => true,
		'publicly_queryable'  => true,
		'show_ui'             => true,
		'show_in_menu'        => true,
		'show_in_nav_menus'   => true,
		'show_in_rest'        => true,
		'has_archive'         => false,
		'hierarchical'        => false,
		'delete_with_user'    => false,
		'capability_type'     => 'post',
		'map_meta_cap'        => true,
		'query_var'           => true,
	);

	// Internal name is ls_product, not product: Kadence reserves "product" for WooCommerce
	// and would hide the title and featured image on single pages. URLs stay /product/...
	if ( ! post_type_exists( 'ls_product' ) ) {
		register_post_type(
			'ls_product',
			array_merge(
				$common,
				array(
					'label'               => '产品',
					'labels'              => liansi_post_type_labels( '产品' ),
					'exclude_from_search' => false,
					'rewrite'             => array( 'slug' => 'product', 'with_front' => true ),
					'menu_position'       => 21,
					'supports'            => array( 'title', 'editor', 'thumbnail', 'excerpt', 'page-attributes' ),
				)
			)
		);
	}

	if ( ! post_type_exists( 'solution' ) ) {
		register_post_type(
			'solution',
			array_merge(
				$common,
				array(
					'label'               => '解决方案',
					'labels'              => liansi_post_type_labels( '解决方案' ),
					'exclude_from_search' => false,
					'rewrite'             => array( 'slug' => 'solution', 'with_front' => true ),
					'menu_position'       => 22,
					'supports'            => array( 'title', 'editor', 'thumbnail', 'excerpt', 'page-attributes' ),
				)
			)
		);
	}

	// Clients only need a name and a logo. They must stay publicly queryable,
	// otherwise the Query Loop block on the home page cannot list them.
	if ( ! post_type_exists( 'client' ) ) {
		register_post_type(
			'client',
			array_merge(
				$common,
				array(
					'label'               => '客户',
					'labels'              => liansi_post_type_labels(
						'客户',
						array(
							'featured_image'     => '客户 Logo',
							'set_featured_image' => '设置客户 Logo',
						)
					),
					'exclude_from_search' => true,
					'rewrite'             => array( 'slug' => 'client', 'with_front' => true ),
					'menu_position'       => 23,
					'supports'            => array( 'title', 'thumbnail', 'page-attributes' ),
				)
			)
		);
	}

	if ( ! taxonomy_exists( 'product_category' ) ) {
		register_taxonomy(
			'product_category',
			array( 'ls_product' ),
			array(
				'label'              => '产品分类',
				'labels'             => array(
					'name'          => '产品分类',
					'singular_name' => '产品分类',
					'menu_name'     => '产品分类',
					'all_items'     => '全部分类',
					'edit_item'     => '编辑分类',
					'add_new_item'  => '添加分类',
					'new_item_name' => '新分类名称',
					'parent_item'   => '上级分类',
					'search_items'  => '搜索分类',
					'not_found'     => '未找到分类',
				),
				'public'             => true,
				'publicly_queryable' => true,
				'hierarchical'       => true,
				'show_ui'            => true,
				'show_in_menu'       => true,
				'show_in_nav_menus'  => true,
				'show_admin_column'  => true,
				'show_in_rest'       => true,
				'query_var'          => true,
				'rewrite'            => array( 'slug' => 'product_category', 'with_front' => true, 'hierarchical' => false ),
			)
		);
	}
}
