package com.dosmartie.inappupdate_demo

import android.content.Intent
import android.os.Bundle
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.IntentSenderRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.tooling.preview.Preview
import androidx.lifecycle.lifecycleScope
import com.dosmartie.inappupdate_demo.ui.theme.InappupdatedemoTheme
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.appupdate.AppUpdateOptions
import com.google.android.play.core.common.IntentSenderForResultStarter
import com.google.android.play.core.install.InstallStateUpdatedListener
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.InstallStatus
import com.google.android.play.core.install.model.UpdateAvailability
import com.google.android.play.core.ktx.isFlexibleUpdateAllowed
import com.google.android.play.core.ktx.isImmediateUpdateAllowed
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {

  private val appUpdateManager by lazy { AppUpdateManagerFactory.create(applicationContext) }
  private val updateType = AppUpdateType.IMMEDIATE

  private val updateResultStarter =
    IntentSenderForResultStarter { intent, _, fillInIntent, flagsMask, flagsValues, _, _ ->
      val request = IntentSenderRequest.Builder(intent).setFillInIntent(fillInIntent)
        .setFlags(flagsValues, flagsMask).build()
      updateLauncher.launch(request)
    }
  private var toastMessage by mutableStateOf("")

  private fun updateAppIfAvailable() {
    appUpdateManager.appUpdateInfo.addOnSuccessListener { appUpdateInfo ->
      val isUpdateAvailable =
        appUpdateInfo.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE
      val isUpdateAllowed = when (updateType) {
        AppUpdateType.FLEXIBLE -> appUpdateInfo.isFlexibleUpdateAllowed
        AppUpdateType.IMMEDIATE -> appUpdateInfo.isImmediateUpdateAllowed
        else -> false
      }
      if (isUpdateAvailable && isUpdateAllowed) {
        appUpdateManager.startUpdateFlowForResult(
          appUpdateInfo, updateResultStarter, AppUpdateOptions.newBuilder(updateType).build(), 123
        )
      }
    }
  }

  private val installStateUpdatedListener = InstallStateUpdatedListener { state ->
    if (state.installStatus() == InstallStatus.DOWNLOADED) {
      toastMessage = "Download successful"
    }
    lifecycleScope.launch {
      delay(5000)
      appUpdateManager.completeUpdate()
    }
  }

  override fun onResume() {
    super.onResume()
    appUpdateManager.appUpdateInfo.addOnSuccessListener { appUpdateInfo ->
      if (updateType == AppUpdateType.IMMEDIATE) {
        if (appUpdateInfo.updateAvailability() == UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS) {
          appUpdateManager.startUpdateFlowForResult( //            appUpdateInfo, updateType, this, 123
            appUpdateInfo, updateResultStarter, AppUpdateOptions.newBuilder(updateType).build(), 123
          )
        }
      }
    }
  }

  private val updateLauncher = registerForActivityResult(
    ActivityResultContracts.StartIntentSenderForResult()
  ) { result ->
    if (result.data == null) return@registerForActivityResult
    if (result.resultCode == 123) {
      toastMessage = "update received"
      if (result.resultCode != 123) {
        toastMessage = "Downloading failed"
      }
    } else if (result.resultCode == RESULT_CANCELED) {
      toastMessage = "Downloading canceled"
    } else {
      toastMessage = "Downloading failed"
    }
  }

//  override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
//    super.onActivityResult(requestCode, resultCode, data)
//    if (requestCode == 123) {
//      if (resultCode != RESULT_OK) {
//        toastMessage = "Something went wrong in updating"
//      }
//    }
//  }

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    enableEdgeToEdge()
    if (updateType == AppUpdateType.FLEXIBLE) {
      appUpdateManager.registerListener(installStateUpdatedListener)
    }
    updateAppIfAvailable()
    setContent {
      InappupdatedemoTheme {
        val context = LocalContext.current
        Scaffold(modifier = Modifier.fillMaxSize()) { innerPadding ->
          Greeting(
            name = "Android", modifier = Modifier.padding(innerPadding)
          )
          Toast.makeText(context, toastMessage, Toast.LENGTH_SHORT).show()
        }
      }
    }
  }

  override fun onDestroy() {
    super.onDestroy()
    if (updateType == AppUpdateType.FLEXIBLE) {
      appUpdateManager.unregisterListener(installStateUpdatedListener)
    }
  }
}

@Composable fun Greeting(name: String, modifier: Modifier = Modifier) {
  Text(
    text = "Hello $name!", modifier = modifier
  )
}

@Preview(showBackground = true) @Composable fun GreetingPreview() {
  InappupdatedemoTheme {
    Greeting("Android")
  }
}