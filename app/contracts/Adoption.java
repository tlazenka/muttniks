package contracts;

import java.math.BigInteger;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import org.web3j.abi.EventEncoder;
import org.web3j.abi.TypeReference;
import org.web3j.abi.datatypes.Address;
import org.web3j.abi.datatypes.Bool;
import org.web3j.abi.datatypes.Event;
import org.web3j.abi.datatypes.Function;
import org.web3j.abi.datatypes.Type;
import org.web3j.abi.datatypes.generated.Bytes32;
import org.web3j.abi.datatypes.generated.Uint256;
import org.web3j.crypto.Credentials;
import org.web3j.protocol.Web3j;
import org.web3j.protocol.core.DefaultBlockParameter;
import org.web3j.protocol.core.RemoteCall;
import org.web3j.protocol.core.methods.request.EthFilter;
import org.web3j.protocol.core.methods.response.Log;
import org.web3j.protocol.core.methods.response.TransactionReceipt;
import org.web3j.tx.Contract;
import org.web3j.tx.TransactionManager;
import rx.Observable;
import rx.functions.Func1;

/**
 * <p>Auto generated code.
 * <p><strong>Do not modify!</strong>
 * <p>Please use the <a href="https://docs.web3j.io/command_line.html">web3j command line tools</a>,
 * or the org.web3j.codegen.SolidityFunctionWrapperGenerator in the 
 * <a href="https://github.com/web3j/web3j/tree/master/codegen">codegen module</a> to update.
 *
 * <p>Generated with web3j version 3.3.1.
 */
public class Adoption extends Contract {
    private static final String BINARY = "0x608060405260018054600160a060020a03191633600160a060020a031617905534801561002b57600080fd5b506105198061003b6000396000f3006080604052600436106100825763ffffffff7c01000000000000000000000000000000000000000000000000000000006000350416630de09c3e81146100875780637541475f146100bb5780637c39eaa3146100e75780638588b2c5146101015780638647f56b14610119578063b7760c8f14610134578063cb44c5f314610158575b600080fd5b34801561009357600080fd5b5061009f60043561016d565b60408051600160a060020a039092168252519081900360200190f35b3480156100c757600080fd5b506100d36004356101b0565b604080519115158252519081900360200190f35b3480156100f357600080fd5b506100ff6004356101f5565b005b34801561010d57600080fd5b506100ff600435610293565b34801561012557600080fd5b506100ff600435602435610368565b34801561014057600080fd5b506100ff600435600160a060020a0360243516610417565b34801561016457600080fd5b5061009f6104c7565b600081815260208190526040812054829060a060020a900460ff16151561019357600080fd5b5050600090815260208190526040902054600160a060020a031690565b600081815260208190526040812054829060a060020a900460ff1615156101d657600080fd5b5050600090815260208190526040902054600160a060020a0316151590565b6101fd6104d6565b60015433600160a060020a0390811691161461021857600080fd5b506040805180820182526000808252600160208084019182529482529381905291909120905181549251151560a060020a0274ff000000000000000000000000000000000000000019600160a060020a039290921673ffffffffffffffffffffffffffffffffffffffff199094169390931716919091179055565b600081815260208190526040902054819060a060020a900460ff1615156102b957600080fd5b600081815260208190526040902054600160a060020a0316156102db57600080fd5b600082815260208190526040902054829060a060020a900460ff16151561030157600080fd5b600083815260208190526040808220805473ffffffffffffffffffffffffffffffffffffffff191633600160a060020a03169081179091559051909185917f01c07ea0ae04d5e8aae2bb4f2d6bf449288c76006383b9ffaed4d85ca8d9a9519190a3505050565b600082815260208190526040902054829060a060020a900460ff16151561038e57600080fd5b60008181526020819052604090205433600160a060020a039081169116146103b557600080fd5b600083815260208190526040902054839060a060020a900460ff1615156103db57600080fd5b60408051848152905185917f81c1028a0bee463ceacb9e56ba0383394952457da330ba49947c730dd72255b5919081900360200190a250505050565b600082815260208190526040902054829060a060020a900460ff16151561043d57600080fd5b60008181526020819052604090205433600160a060020a0390811691161461046457600080fd5b600083815260208190526040902054839060a060020a900460ff16151561048a57600080fd5b5050600091825260208290526040909120805473ffffffffffffffffffffffffffffffffffffffff1916600160a060020a03909216919091179055565b600154600160a060020a031681565b6040805180820190915260008082526020820152905600a165627a7a72305820c01d094b867f14abd40a492fde17db76de765a75625461523d760e9199c2e8b60029";

    protected static final HashMap<String, String> _addresses;

    static {
        _addresses = new HashMap<>();
        _addresses.put("1549151450391", "0x345ca3e014aaf5dca488057592ee47305d9b3e10");
        _addresses.put("1549146592264", "0x345ca3e014aaf5dca488057592ee47305d9b3e10");
        _addresses.put("1549144931260", "0x345ca3e014aaf5dca488057592ee47305d9b3e10");
        _addresses.put("1549150230859", "0x345ca3e014aaf5dca488057592ee47305d9b3e10");
        _addresses.put("1549147027190", "0x345ca3e014aaf5dca488057592ee47305d9b3e10");
        _addresses.put("1549149770907", "0x345ca3e014aaf5dca488057592ee47305d9b3e10");
        _addresses.put("1549141439742", "0x345ca3e014aaf5dca488057592ee47305d9b3e10");
        _addresses.put("1549079477728", "0x345ca3e014aaf5dca488057592ee47305d9b3e10");
    }

    protected Adoption(String contractAddress, Web3j web3j, Credentials credentials, BigInteger gasPrice, BigInteger gasLimit) {
        super(BINARY, contractAddress, web3j, credentials, gasPrice, gasLimit);
    }

    protected Adoption(String contractAddress, Web3j web3j, TransactionManager transactionManager, BigInteger gasPrice, BigInteger gasLimit) {
        super(BINARY, contractAddress, web3j, transactionManager, gasPrice, gasLimit);
    }

    public List<NameAssignedEventResponse> getNameAssignedEvents(TransactionReceipt transactionReceipt) {
        final Event event = new Event("NameAssigned", 
                Arrays.<TypeReference<?>>asList(new TypeReference<Uint256>() {}),
                Arrays.<TypeReference<?>>asList(new TypeReference<Bytes32>() {}));
        List<Contract.EventValuesWithLog> valueList = extractEventParametersWithLog(event, transactionReceipt);
        ArrayList<NameAssignedEventResponse> responses = new ArrayList<NameAssignedEventResponse>(valueList.size());
        for (Contract.EventValuesWithLog eventValues : valueList) {
            NameAssignedEventResponse typedResponse = new NameAssignedEventResponse();
            typedResponse.log = eventValues.getLog();
            typedResponse.petId = (BigInteger) eventValues.getIndexedValues().get(0).getValue();
            typedResponse.name = (byte[]) eventValues.getNonIndexedValues().get(0).getValue();
            responses.add(typedResponse);
        }
        return responses;
    }

    public Observable<NameAssignedEventResponse> nameAssignedEventObservable(DefaultBlockParameter startBlock, DefaultBlockParameter endBlock) {
        final Event event = new Event("NameAssigned", 
                Arrays.<TypeReference<?>>asList(new TypeReference<Uint256>() {}),
                Arrays.<TypeReference<?>>asList(new TypeReference<Bytes32>() {}));
        EthFilter filter = new EthFilter(startBlock, endBlock, getContractAddress());
        filter.addSingleTopic(EventEncoder.encode(event));
        return web3j.ethLogObservable(filter).map(new Func1<Log, NameAssignedEventResponse>() {
            @Override
            public NameAssignedEventResponse call(Log log) {
                Contract.EventValuesWithLog eventValues = extractEventParametersWithLog(event, log);
                NameAssignedEventResponse typedResponse = new NameAssignedEventResponse();
                typedResponse.log = log;
                typedResponse.petId = (BigInteger) eventValues.getIndexedValues().get(0).getValue();
                typedResponse.name = (byte[]) eventValues.getNonIndexedValues().get(0).getValue();
                return typedResponse;
            }
        });
    }

    public List<AdoptedEventResponse> getAdoptedEvents(TransactionReceipt transactionReceipt) {
        final Event event = new Event("Adopted", 
                Arrays.<TypeReference<?>>asList(new TypeReference<Uint256>() {}, new TypeReference<Address>() {}),
                Arrays.<TypeReference<?>>asList());
        List<Contract.EventValuesWithLog> valueList = extractEventParametersWithLog(event, transactionReceipt);
        ArrayList<AdoptedEventResponse> responses = new ArrayList<AdoptedEventResponse>(valueList.size());
        for (Contract.EventValuesWithLog eventValues : valueList) {
            AdoptedEventResponse typedResponse = new AdoptedEventResponse();
            typedResponse.log = eventValues.getLog();
            typedResponse.petId = (BigInteger) eventValues.getIndexedValues().get(0).getValue();
            typedResponse.adopter = (String) eventValues.getIndexedValues().get(1).getValue();
            responses.add(typedResponse);
        }
        return responses;
    }

    public Observable<AdoptedEventResponse> adoptedEventObservable(DefaultBlockParameter startBlock, DefaultBlockParameter endBlock) {
        final Event event = new Event("Adopted", 
                Arrays.<TypeReference<?>>asList(new TypeReference<Uint256>() {}, new TypeReference<Address>() {}),
                Arrays.<TypeReference<?>>asList());
        EthFilter filter = new EthFilter(startBlock, endBlock, getContractAddress());
        filter.addSingleTopic(EventEncoder.encode(event));
        return web3j.ethLogObservable(filter).map(new Func1<Log, AdoptedEventResponse>() {
            @Override
            public AdoptedEventResponse call(Log log) {
                Contract.EventValuesWithLog eventValues = extractEventParametersWithLog(event, log);
                AdoptedEventResponse typedResponse = new AdoptedEventResponse();
                typedResponse.log = log;
                typedResponse.petId = (BigInteger) eventValues.getIndexedValues().get(0).getValue();
                typedResponse.adopter = (String) eventValues.getIndexedValues().get(1).getValue();
                return typedResponse;
            }
        });
    }

    public RemoteCall<String> contractOwnerAddress() {
        final Function function = new Function("contractOwnerAddress", 
                Arrays.<Type>asList(), 
                Arrays.<TypeReference<?>>asList(new TypeReference<Address>() {}));
        return executeRemoteCallSingleValueReturn(function, String.class);
    }

    public RemoteCall<TransactionReceipt> transfer(BigInteger petId, String to) {
        final Function function = new Function(
                "transfer", 
                Arrays.<Type>asList(new org.web3j.abi.datatypes.generated.Uint256(petId), 
                new org.web3j.abi.datatypes.Address(to)), 
                Collections.<TypeReference<?>>emptyList());
        return executeRemoteCallTransaction(function);
    }

    public RemoteCall<TransactionReceipt> createAdoptee(BigInteger petId) {
        final Function function = new Function(
                "createAdoptee", 
                Arrays.<Type>asList(new org.web3j.abi.datatypes.generated.Uint256(petId)), 
                Collections.<TypeReference<?>>emptyList());
        return executeRemoteCallTransaction(function);
    }

    public RemoteCall<String> adopterOf(BigInteger petId) {
        final Function function = new Function("adopterOf", 
                Arrays.<Type>asList(new org.web3j.abi.datatypes.generated.Uint256(petId)), 
                Arrays.<TypeReference<?>>asList(new TypeReference<Address>() {}));
        return executeRemoteCallSingleValueReturn(function, String.class);
    }

    public RemoteCall<TransactionReceipt> adopt(BigInteger petId) {
        final Function function = new Function(
                "adopt", 
                Arrays.<Type>asList(new org.web3j.abi.datatypes.generated.Uint256(petId)), 
                Collections.<TypeReference<?>>emptyList());
        return executeRemoteCallTransaction(function);
    }

    public RemoteCall<Boolean> isAdopted(BigInteger petId) {
        final Function function = new Function("isAdopted", 
                Arrays.<Type>asList(new org.web3j.abi.datatypes.generated.Uint256(petId)), 
                Arrays.<TypeReference<?>>asList(new TypeReference<Bool>() {}));
        return executeRemoteCallSingleValueReturn(function, Boolean.class);
    }

    public RemoteCall<TransactionReceipt> assignName(BigInteger petId, byte[] name) {
        final Function function = new Function(
                "assignName", 
                Arrays.<Type>asList(new org.web3j.abi.datatypes.generated.Uint256(petId), 
                new org.web3j.abi.datatypes.generated.Bytes32(name)), 
                Collections.<TypeReference<?>>emptyList());
        return executeRemoteCallTransaction(function);
    }

    public static RemoteCall<Adoption> deploy(Web3j web3j, Credentials credentials, BigInteger gasPrice, BigInteger gasLimit) {
        return deployRemoteCall(Adoption.class, web3j, credentials, gasPrice, gasLimit, BINARY, "");
    }

    public static RemoteCall<Adoption> deploy(Web3j web3j, TransactionManager transactionManager, BigInteger gasPrice, BigInteger gasLimit) {
        return deployRemoteCall(Adoption.class, web3j, transactionManager, gasPrice, gasLimit, BINARY, "");
    }

    public static Adoption load(String contractAddress, Web3j web3j, Credentials credentials, BigInteger gasPrice, BigInteger gasLimit) {
        return new Adoption(contractAddress, web3j, credentials, gasPrice, gasLimit);
    }

    public static Adoption load(String contractAddress, Web3j web3j, TransactionManager transactionManager, BigInteger gasPrice, BigInteger gasLimit) {
        return new Adoption(contractAddress, web3j, transactionManager, gasPrice, gasLimit);
    }

    protected String getStaticDeployedAddress(String networkId) {
        return _addresses.get(networkId);
    }

    public static String getPreviouslyDeployedAddress(String networkId) {
        return _addresses.get(networkId);
    }

    public static class NameAssignedEventResponse {
        public Log log;

        public BigInteger petId;

        public byte[] name;
    }

    public static class AdoptedEventResponse {
        public Log log;

        public BigInteger petId;

        public String adopter;
    }
}
