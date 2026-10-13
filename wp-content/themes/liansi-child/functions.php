<?php
/**
 * Liansi Child theme functions.
 *
 * Kadence loads its own stylesheets; the child only adds style.css on top.
 */

defined( 'ABSPATH' ) || exit;

add_action(
	'wp_enqueue_scripts',
	function () {
		wp_enqueue_style( 'liansi-child', get_stylesheet_uri(), array(), wp_get_theme()->get( 'Version' ) );
	},
	20
);
