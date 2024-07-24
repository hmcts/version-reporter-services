import pytest
import os
from unittest.mock import patch, MagicMock

from main import get_minor_version, main

def test_get_minor_version():
    assert get_minor_version("1.2.3") == 2.0
    assert get_minor_version("4.5.6") == 5.0

@patch('main.DefaultAzureCredential')
@patch('main.SubscriptionClient')
@patch('main.ContainerServiceClient')
@patch('main.CosmosClient')
def test_main_script(mock_cosmos_client, mock_container_service_client, mock_subscription_client, mock_default_credential):

    os.environ['COSMOS_DB_URI'] = 'URI'

    # Mock the Azure credential
    mock_default_credential.return_value = MagicMock()

    # Mock the SubscriptionClient
    mock_subscription = MagicMock()
    mock_subscription.subscriptions.list.return_value = [mock_subscription]
    mock_subscription.subscriptions.get.return_value = MagicMock(display_name='CFT')
    mock_subscription_client.return_value = mock_subscription

    # Mock the ContainerServiceClient
    mock_container_service = MagicMock()
    mock_container_service.managed_clusters.list.return_value = []
    mock_container_service_client.return_value = mock_container_service

    # Mock the CosmosClient
    mock_cosmos = MagicMock()
    mock_cosmos.get_database_client.return_value = MagicMock()
    mock_cosmos_client.return_value = mock_cosmos

    # Call your main script function here
    main()

    mock_subscription_client.assert_called_once_with(mock_default_credential.return_value)
    mock_subscription_client.return_value.subscriptions.get.assert_called_once_with(mock_subscription_client.return_value.subscription_id)
    assert 'CFT' in mock_subscription_client.return_value.subscriptions.get.return_value.display_name

    mock_container_service_client.assert_called_once_with(mock_default_credential.return_value, mock_subscription_client.return_value.subscription_id)
    mock_container_service.managed_clusters.list.assert_called_once()

    mock_cosmos_client.assert_called_once_with(os.environ['COSMOS_DB_URI'], credential=mock_default_credential.return_value)
    mock_cosmos.get_database_client.assert_called_once()
