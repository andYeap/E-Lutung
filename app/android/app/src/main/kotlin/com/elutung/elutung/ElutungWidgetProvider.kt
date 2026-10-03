package com.elutung.elutung

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Widget beranda (Bagian FR-9). Data ditulis dari sisi Dart lewat `home_widget`
 * (kunci `widget_*`), lalu dirender di sini dengan RemoteViews.
 */
class ElutungWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val data = HomeWidgetPlugin.getData(context)

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_elutung)

            views.setTextViewText(
                R.id.widget_income,
                data.getString("widget_income_month", "Masuk: -")
            )
            views.setTextViewText(
                R.id.widget_expense,
                data.getString("widget_expense_month", "Keluar: -")
            )
            views.setTextViewText(
                R.id.widget_budget_remaining,
                data.getString("widget_budget_remaining", "Anggaran: belum disetel")
            )
            views.setTextViewText(
                R.id.widget_budget_pct,
                data.getString("widget_budget_pct", "")
            )
            // Indikator warna hijau->merah (FR-9.3).
            val budgetColor = data.getString("widget_budget_color", "#3A3934")
            val parsedBudgetColor = try {
                android.graphics.Color.parseColor(budgetColor)
            } catch (_: Exception) {
                android.graphics.Color.parseColor("#3A3934")
            }
            views.setTextColor(R.id.widget_budget_remaining, parsedBudgetColor)
            views.setTextColor(R.id.widget_budget_pct, parsedBudgetColor)
            // 1-3 aktivitas terbaru (FR-9.1).
            views.setTextViewText(
                R.id.widget_latest_1,
                data.getString("widget_latest_1", "Belum ada transaksi")
            )
            views.setTextViewText(
                R.id.widget_latest_2,
                data.getString("widget_latest_2", "")
            )
            views.setTextViewText(
                R.id.widget_latest_3,
                data.getString("widget_latest_3", "")
            )

            // FR-9.6: ketukan membuka aplikasi; URI dibaca Dart untuk
            // melompat langsung ke detail transaksi terbaru.
            val pending = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("elutung://open?target=latest"),
            )
            views.setOnClickPendingIntent(R.id.widget_root, pending)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
