package helpers;

import okhttp3.OkHttpClient;
import org.web3j.abi.EventValues;
import org.web3j.abi.TypeReference;
import org.web3j.abi.datatypes.Event;
import org.web3j.abi.datatypes.Type;
import org.web3j.abi.datatypes.generated.Bytes32;
import org.web3j.abi.datatypes.generated.Uint256;
import org.web3j.protocol.Web3j;
import org.web3j.protocol.core.DefaultBlockParameter;
import org.web3j.protocol.core.methods.request.EthFilter;
import org.web3j.protocol.core.methods.response.EthBlockNumber;
import org.web3j.protocol.core.methods.response.EthLog;
import org.web3j.protocol.core.methods.response.Log;
import org.web3j.protocol.http.HttpService;
import org.web3j.tx.Contract;

import java.io.IOException;
import java.io.UnsupportedEncodingException;
import java.math.BigInteger;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.concurrent.TimeUnit;

public final class Web3jHelpers {
    private final static String web3HttpServicePrivateUrl = System.getenv("ETH_PRIVATE_URL");

    private final static String adoptionContractAddress = System.getenv("ETH_ADOPTION_CONTRACT_ADDRESS");

    private final static String nameAssignedTopic = System.getenv("ETH_NAME_ASSIGNED_TOPIC");

    private final static Long timeoutSeconds = Long.parseLong(System.getenv("WEB3J_TIMEOUT_SECONDS"));

    private final static OkHttpClient httpClient  = new OkHttpClient.Builder()
            .connectTimeout(timeoutSeconds, TimeUnit.SECONDS)
            .readTimeout(timeoutSeconds, TimeUnit.SECONDS)
            .writeTimeout(timeoutSeconds, TimeUnit.SECONDS)
            .build();


    private final static Web3j web3j = Web3j.build(new HttpService(web3HttpServicePrivateUrl, httpClient, false));

    private static List<String> getAssignedNames(final BigInteger startBlock, final BigInteger endBlock, final long externalId) throws IOException {
        final EthFilter ethFilter = ethNamesFilterForContractAddress(adoptionContractAddress, nameAssignedTopic, startBlock, endBlock, externalId);
        final EthLog logs = web3j.ethGetLogs(ethFilter).send();
        return getNamesFromLogResults(logs.getLogs());
    }

    public static String getLastAssignedName(final long externalId) throws IOException {
        return getLastAssignedName(null, null, externalId);
    }

    public static String getLastAssignedName(final BigInteger startBlock, final BigInteger endBlock, final long externalId) throws IOException {
        final List<String> names = getAssignedNames(startBlock, endBlock, externalId);

        if ((names == null) || (names.size() <= 0)) {
            return null;
        }

        return names.get(names.size() - 1);
    }

    public static BigInteger getLatestBlockNumber() throws IOException {
        EthBlockNumber result = web3j.ethBlockNumber().send();
        return result.getBlockNumber();
    }

    private static EthFilter ethNamesFilterForContractAddress(
            final String contractAddress,
            final String topic,
            final BigInteger startBlock,
            final BigInteger endBlock,
            final long externalId) {
        final ArrayList<String> addresses = new ArrayList<>();
        addresses.add(contractAddress);

        final DefaultBlockParameter fromBlock =
                (startBlock == null) ? (DefaultBlockParameter.valueOf(BigInteger.ZERO)) : (DefaultBlockParameter.valueOf(startBlock));

        final DefaultBlockParameter toBlock =
                (endBlock == null) ? (DefaultBlockParameter.valueOf("latest")) : (DefaultBlockParameter.valueOf(endBlock));

        EthFilter ethFilter = new EthFilter(fromBlock, toBlock, addresses);

        ethFilter.addSingleTopic(topic);
        ethFilter.addOptionalTopics(Helpers.toHexString(externalId, 64));

        return ethFilter;
    }

    public static List<String> getNamesFromLogResults(final List<EthLog.LogResult> logResults) throws UnsupportedEncodingException {
        final ArrayList<String> result = new ArrayList<>();

        final Event nameAssignedEvent = new Event("NameAssigned",
                Arrays.<TypeReference<?>>asList(new TypeReference<Uint256>() {}),
                Arrays.<TypeReference<?>>asList(new TypeReference<Bytes32>() {}));

        for (final EthLog.LogResult logResult: logResults) {
            if (!(logResult instanceof EthLog.LogObject)) {
                continue;
            }
            final EthLog.LogObject logObject = (EthLog.LogObject) logResult;
            final Log log = logObject.get();
            final EventValues eventValues = Contract.staticExtractEventParameters(nameAssignedEvent, log);
            final List<Type> nonIndexedValues = eventValues.getNonIndexedValues();
            if (nonIndexedValues.size() < 1) {
                continue;
            }

            final Object value = eventValues.getNonIndexedValues().get(0).getValue();

            if (!(value instanceof byte[])) {
                continue;
            }

            final byte[] name = (byte[])value;
            result.add(new String(name, "UTF-8"));
        }

        return result;
    }

}
