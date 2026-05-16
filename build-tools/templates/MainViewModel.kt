package {{PACKAGE}}

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class MainUiState(
    val message: String = "Ready",
    val isLoading: Boolean = false,
    val error: String? = null
)

class MainViewModel : ViewModel() {

    private val _uiState = MutableStateFlow(MainUiState())
    val uiState: StateFlow<MainUiState> = _uiState.asStateFlow()

    fun onActionClicked() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, message = "Loading...") }

            // TODO: call repository here
            // val result = repository.fetchData()

            _uiState.update { it.copy(isLoading = false, message = "Done!") }
        }
    }
}